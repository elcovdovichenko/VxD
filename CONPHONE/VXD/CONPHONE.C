
#define WANTVXDWRAPS

#include <basedef.h>
#include <vmm.h>
#include <debug.h>
#include <vxdwraps.h>
#include <vwin32.h>
#include <winerror.h>
#include <vpicd.h>
#include <shell.h>

typedef DIOCPARAMETERS *LPDIOC;

#define LEADER_OUT 0x4B
#define LEADER_IN 0x4F
#define INT_IRQ_ALL_OFF 0
#define INT_IRQ_RECEIVE_ON 1
#define INT_IRQ_TRANSMIT_ON 2
#define MAX_SIZE_BUFF 128

#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG

//------------------ VXD GLOBAL VARIABLES -----------------------------------

//Post_Message mechanism
ULONG hWindow;
DWORD wm_Message;

// IRQ Control
BYTE nIRQ;                                       // IRQ Number
HIRQ hIRQ = 0;                                   // IRQ Handle
VID IRQDesc;                                     // VPCID_IRQ_Descriptor
DWORD sIRQ;                                      // IRQ Status

//UART Control
BYTE cycles = 0;                                 // number of cycles
DWORD addrUART[2] = {0x260,0x270};               // UART base address
DWORD addrMx = 0x268;                            // channel multiplexsor
WORD koefSpeed = 115;                            // speed koefficient
BYTE modeUART = 7;                               // UART mode
BYTE points[2] = {16,8};                         // points in cycle
BYTE accessMx[2][16] =                           // multiplex codes
       {{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
        {0,1,2,3,4,5,6,7,0,8,16,24,32,40,48,56}};
BYTE clearMx[2][2] = {{0xF0,0},{0xF8,0xC7}};     // multiplexsor masks
BYTE multiplexor = 0;                            // multiplexsor current code
BYTE cTransmit[2] = {0,0};                       // transmit counters
BYTE sInt[2] = {0,0};                            // UART states
BOOL isLeader[2] = {FALSE,FALSE};                // LEADER_IN is received
BYTE *pTransmit[2] = {0,0};                      // transmit buffer pointers
BYTE *pReceive[2] = {0,0};                       // receive buffer pointers
HTIMEOUT hTimeOut[2] = {0,0};                    // timeOut handlers
HTIMEOUT hTimePush[2] = {0,0};                   // push timeOut handlers
BYTE currentKey[2] = {0,0};                      // current cycle's key

//Debugging
ULONG breaksTransmit[16] =                       // transmit breaks
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
ULONG breaksReceive[16] =                        // receive breaks
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
ULONG breaksTimeOut[16] =                        // timeout breaks
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
ULONG breaksError[16] =                          // error breaks
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
ULONG intError[16] =                             // interface error
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
ULONG countTransmit[16] =                        //
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
ULONG countAbsent[16] =                          //
        {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

//---------------------- VxD CALLs ------------------------------------------

DWORD _stdcall CVXD_W32_DeviceIOControl(DWORD, DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_CleanUp(void);
DWORD _stdcall CVXD_W32_Proc1(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc2(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc3(DWORD, DWORD, LPDIOC);
DWORD ( _stdcall *CVxD_W32_Proc[] )(DWORD, DWORD, LPDIOC) = {
        CVXD_W32_Proc1,
        CVXD_W32_Proc2,
        CVXD_W32_Proc3};
#define MAX_CVXD_W32_API (sizeof(CVxD_W32_Proc)/sizeof(DWORD))

//-------------- Vxd Declared Functions -------------------------------------

VOID  CVXD_Hw_Int(void);
VOID  CVXD_Time_Int(void);
VOID  CVXD_Start_TimeOut(DWORD cycle);
VOID  CVXD_Stop_TimeOut(DWORD cycle);
VOID  CVXD_Time_Push(void);
VOID  CVXD_Start_Push(DWORD cycle);
VOID  CVXD_Stop_Push(DWORD cycle);
HIRQ  CVXD_Hook_Irq(void);
VOID  CVXD_Reset_Irq(void);
BYTE  CVXD_Init_UART(DWORD iobase);
BYTE  CVXD_State_UART(DWORD iobase);
BYTE  CVXD_Transmit_UART(DWORD iobase, BYTE sym);
BYTE  CVXD_Receive_UART(DWORD iobase, PBYTE sym);
VOID  CVXD_Mask_UART(DWORD iobase, BYTE mask);
BOOL  CVXD_Is_UART_IRQs(DWORD iobase, PBYTE require);
VOID  CVXD_Set_Multiplexsor(BYTE key);
VOID  CVXD_Init_Multiplexsor(void);

/****************************************************************************
                  CVXD_W32_DeviceIOControl
****************************************************************************/
DWORD _stdcall CVXD_W32_DeviceIOControl(DWORD  dwService,
                                        DWORD  dwDDB,
                                        DWORD  hDevice,
                                        LPDIOC lpDIOCParms)
{
    DWORD dwRetVal = 0;

    // DIOC_OPEN is sent when VxD is loaded by CreateFile
    //  (this happens just after SYS_DYNAMIC_INIT)
    if ( dwService == DIOC_OPEN )
    {
        //Out_Debug_String("CONPHONE: WIN32 DEVIOCTL supported here!\n\r");
        // Must return 0 to tell WIN32 that this VxD supports DEVIOCTL
        dwRetVal = hIRQ; // VxD reload protection
    }
    // DIOC_CLOSEHANDLE is sent when VxD is unloaded by CloseHandle
    //  (this happens just before SYS_DYNAMIC_EXIT)
    else if ( dwService == DIOC_CLOSEHANDLE )
    {
        // Dispatch to cleanup proc
        dwRetVal = CVXD_CleanUp();
    }
    else if ( dwService > MAX_CVXD_W32_API )
    {
        // Returning a positive value will cause the WIN32 DeviceIOControl
        // call to return FALSE, the error code can then be retrieved
        // via the WIN32 GetLastError
        dwRetVal = ERROR_NOT_SUPPORTED;
    }
    else
    {
        // CALL requested service
        dwRetVal = (CVxD_W32_Proc[dwService-1])(dwDDB, hDevice, lpDIOCParms);
    }
    return(dwRetVal);
}

// Controller Initialization
DWORD _stdcall CVXD_W32_Proc1(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE cycle;

    //Out_Debug_String("CONPHONE: CVXD_W32_Proc1\n\r");

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    nIRQ = pdwi[0];                              //
    addrUART[0] = pdwi[1];                       //
    addrMx = addrUART[0] + 8;                    //
    addrUART[1] = addrUART[0] + 16;              //
    hWindow = pdwi[2];                           //
    wm_Message = pdwi[3];                        //
    cycle = pdwi[4];                             //
    if (cycle < 2) cycles = cycle;               //

    pReceive[0] = _HeapAllocate(MAX_SIZE_BUFF,0);//
    *pReceive[0] = 0;                            //
    pTransmit[0] = _HeapAllocate(MAX_SIZE_BUFF,0);//
    *pTransmit[0] = 0;                           //
    pReceive[1] = _HeapAllocate(MAX_SIZE_BUFF,0);//
    *pReceive[1] = 0;                            //
    pTransmit[1] = _HeapAllocate(MAX_SIZE_BUFF,0);//
    *pTransmit[1] = 0;                           //

    hIRQ = CVXD_Hook_Irq();                      //
    sIRQ = VPICD_Get_IRQ_Complete_Status(nIRQ);  //
    if (hIRQ != 0)
    {
       CVXD_Init_Multiplexsor();                 //
       CVXD_Set_Multiplexsor(0);                 //
       for (cycle = 0; cycle <= cycles; cycle++) //
       {
          sInt[cycle] = CVXD_Init_UART(addrUART[cycle]);
       }
    }

    pdwo[0] = hIRQ;                              //
    pdwo[1] = sIRQ;                              //
    pdwo[2] = pReceive[0];                       //
    pdwo[3] = pTransmit[0];                      //
    pdwo[4] = pReceive[1];                       //
    pdwo[5] = pTransmit[1];                      //
    pdwo[6] = sInt;                              //
    pdwo[7] = breaksTransmit;                    //
    pdwo[8] = countTransmit;                     //
    pdwo[9] = intError;                          //

    return(NO_ERROR);
}

// Start transmision
DWORD _stdcall CVXD_W32_Proc2(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwi;
    BYTE key, cycle;

    //Out_Debug_String("CONPHONE: CVXD_W32_Proc2\n\r");

    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    key = pdwi[0];
    cycle = key/points[cycles];
    currentKey[cycle] = key;
    if (*pTransmit[cycle] > 0)
    {
      breaksTransmit[currentKey[cycle]]++;

      CVXD_Set_Multiplexsor(key);
      cTransmit[cycle] = 0;
      *pReceive[cycle] = 0;
      isLeader[cycle] = FALSE;

      sInt[cycle] = CVXD_Transmit_UART(addrUART[cycle], LEADER_OUT);
      CVXD_Mask_UART(addrUART[cycle], INT_IRQ_TRANSMIT_ON);

      CVXD_Start_Push(cycle);
    }
    else
    {
      sInt[cycle] = 0;
      *pReceive[cycle] = 0;
     _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, currentKey[cycle], 0, NULL, 0);
    }
    return(NO_ERROR);
}

//Reset Timeouts and Interrupt
DWORD _stdcall CVXD_W32_Proc3(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    BYTE cycle;

    CVXD_Reset_Irq();
    hIRQ = 0;

    for (cycle = 0; cycle <= cycles; cycle++)
    {
       CVXD_Stop_Push(cycle);
       CVXD_Stop_TimeOut(cycle);
    }

    if (pReceive[0] != 0) _HeapFree(pReceive[0],0);
    if (pReceive[1] != 0) _HeapFree(pReceive[1],0);
    if (pTransmit[0] != 0) _HeapFree(pTransmit[0],0);
    if (pTransmit[1] != 0) _HeapFree(pTransmit[1],0);

    return(NO_ERROR);
}

// Dispatch IOCTL Event SYS_DYNAMIC_DEVICE_EXIT
DWORD _stdcall CVXD_Dynamic_Exit(void)
{
    //Out_Debug_String("CONPHONE: Dynamic Exit\n\r");
    return(VXD_SUCCESS);
}

// Dispatch IOCTL Event DIOC_CLOSEHANDLE
DWORD _stdcall CVXD_CleanUp(void)
{
    //Out_Debug_String("CONPHONE: Cleaning Up\n\r");

    return(VXD_SUCCESS);
}

// Intrrupt Handler
VOID  CVXD_Hw_Int(void)
{
    BYTE cycle, req, rInt, len;

    __asm
    {
       cli
       pushad
    }

    while (TRUE)
    {
      for (cycle = 0; cycle <= cycles; cycle++)
      {
        while (TRUE)
        {
          if (!CVXD_Is_UART_IRQs(addrUART[cycle],&req)) break;

          switch(req)
          {
          case 2: // Transmit the symbol
            CVXD_Stop_Push(cycle);
            if (*pTransmit[cycle] > cTransmit[cycle])
            {
              cTransmit[cycle]++;
              sInt[cycle] = CVXD_Transmit_UART(addrUART[cycle],*(pTransmit[cycle]+cTransmit[cycle]));
              if ((sInt[cycle] & 0x20) == 0) cTransmit[cycle]--;
            }
            if (*pTransmit[cycle] == cTransmit[cycle])
            {
              breaksTransmit[currentKey[cycle]]--;
              CVXD_Mask_UART(addrUART[cycle], INT_IRQ_RECEIVE_ON);
              CVXD_Start_TimeOut(cycle);
            }
            else CVXD_Start_Push(cycle);
            break;
          case 4: // Receive the symbol
            sInt[cycle] = CVXD_Receive_UART(addrUART[cycle],&rInt);
            if ((sInt[cycle] & 0x1F) == 1)
            {
              //is LEADER_IN received?
              if (!isLeader[cycle])
              {
                isLeader[cycle] = (rInt == LEADER_IN);
                *pReceive[cycle] = 0;
                if (isLeader[cycle]) breaksReceive[currentKey[cycle]]++;
                break;
              }

              //the following simbol is received
              if (*pReceive[cycle] < MAX_SIZE_BUFF)
              {
                (*pReceive[cycle])++;
                *(pReceive[cycle]+(*pReceive[cycle])) = rInt;
              }
              else break;

              //is LEADER_IN received inside protocol package?
              if (rInt == LEADER_IN)
              {
                *pReceive[cycle] = 0;
                break;
              }

              //calculate the protocol package length
              rInt = *(pReceive[cycle]+1);
              if ((rInt & 0x10) == 0x10)
              {
                len = ((rInt & 0x0F) + 2);
              }
              else
              {
                len = ((rInt & 0x07) + 2);
              }

              //is protocol package received?
              if ((*pReceive[cycle]) == len)
              {
                breaksReceive[currentKey[cycle]]--;

                CVXD_Stop_TimeOut(cycle);
                CVXD_Mask_UART(addrUART[cycle], INT_IRQ_ALL_OFF);
                isLeader[cycle] = FALSE;
                sInt[cycle] = (sInt[cycle] & 0x7F);
                _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, currentKey[cycle], 0, NULL, 0);

              }
              else CVXD_Start_TimeOut(cycle);
            }
            else //the interface error is occuired
            {
              breaksError[currentKey[cycle]]++;
              intError[currentKey[cycle]] = sInt[cycle];

              sInt[cycle] = (sInt[cycle] | 0x80);
              CVXD_Stop_TimeOut(cycle);
              CVXD_Mask_UART(addrUART[cycle], INT_IRQ_ALL_OFF);
              isLeader[cycle] = FALSE;
              _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, currentKey[cycle], 0, NULL, 0);
            }
            break;
          }
        }
      }
    //are all interrups processed?
    if ((cycles == 0) ||
        !(CVXD_Is_UART_IRQs(addrUART[0],&req) || CVXD_Is_UART_IRQs(addrUART[1],&req)))
      break;
    }
    VPICD_Phys_EOI(hIRQ);

    __asm
    {
       popad
       sti
    }
}

//Timeing Receive
VOID  CVXD_Time_Int(void)
{
    DWORD cycle;
    __asm
    {
       cli
       mov cycle,edx
    }

    breaksTimeOut[currentKey[cycle]]++;

    sInt[cycle] = 0x80;
    CVXD_Stop_TimeOut(cycle);
    CVXD_Init_UART(addrUART[cycle]); //переинициализация интерфейса!!!
    CVXD_Mask_UART(addrUART[cycle], INT_IRQ_ALL_OFF);
    isLeader[cycle] = FALSE;
    _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, currentKey[cycle], 0, NULL, 0);

    __asm
    {
       sti
    }
}

// Start TimeOut
VOID  CVXD_Start_TimeOut(DWORD cycle)
{
    if (hTimeOut[cycle] != 0) Cancel_Time_Out(hTimeOut[cycle]);
    hTimeOut[cycle] = Set_Async_Time_Out(&CVXD_Time_Int, 150, cycle);
}

// Stop TimeOut
VOID  CVXD_Stop_TimeOut(DWORD cycle)
{
    if (hTimeOut[cycle] != 0) Cancel_Time_Out(hTimeOut[cycle]);
    hTimeOut[cycle] = 0;
}

//Timeing Push Transmit
VOID  CVXD_Time_Push(void)
{
    DWORD cycle;
    __asm
    {
       cli
       mov cycle,edx
    }

    countTransmit[currentKey[cycle]]++;

    if (*pTransmit[cycle] > cTransmit[cycle])
    {
      cTransmit[cycle]++;
      sInt[cycle] = CVXD_Transmit_UART(addrUART[cycle],*(pTransmit[cycle]+cTransmit[cycle]));
      if ((sInt[cycle] & 0x20) == 0)
      {
        countAbsent[currentKey[cycle]]++;

        cTransmit[cycle]--;
        sInt[cycle] = 0x9E;
        CVXD_Stop_Push(cycle);
        CVXD_Mask_UART(addrUART[cycle], INT_IRQ_ALL_OFF);
        isLeader[cycle] = FALSE;
        _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, currentKey[cycle], 0, NULL, 0);
      }
      else
      {
        if (*pTransmit[cycle] <= cTransmit[cycle])
        {
          breaksTransmit[currentKey[cycle]]--;
          CVXD_Mask_UART(addrUART[cycle], INT_IRQ_RECEIVE_ON);
          CVXD_Stop_Push(cycle);
          CVXD_Start_TimeOut(cycle);
        }
        else CVXD_Start_Push(cycle);
      }
    }
    else CVXD_Stop_Push(cycle);

    __asm
    {
       sti
    }
}

// Start Push Transmit TimeOut
VOID  CVXD_Start_Push(DWORD cycle)
{
    if (hTimePush[cycle] != 0) Cancel_Time_Out(hTimePush[cycle]);
    hTimePush[cycle] = Set_Async_Time_Out(&CVXD_Time_Push, 10, cycle);
}

// Stop Push Transmit TimeOut
VOID  CVXD_Stop_Push(DWORD cycle)
{
    if (hTimePush[cycle] != 0) Cancel_Time_Out(hTimePush[cycle]);
    hTimePush[cycle] = 0;
}

//Hooks definite IRQ
HIRQ  CVXD_Hook_Irq(void)
{
    HIRQ handle;

    IRQDesc.VID_IRQ_Number = nIRQ;
    //IRQDesc.VID_Options = VPICD_OPT_READ_HW_IRR;
    IRQDesc.VID_Hw_Int_Proc = &CVXD_Hw_Int;

    handle = VPICD_Virtualize_IRQ(&IRQDesc);
    if (handle != 0)
    {
       VPICD_Phys_EOI(handle);
       VPICD_Physically_Unmask(handle);
    }

    return(handle);
}

//Release definit IRQ
VOID  CVXD_Reset_Irq(void)
{
    BYTE cycle;

    if (hIRQ != 0)
    {
       for (cycle = 0; cycle <= cycles; cycle++)
       {
          CVXD_Mask_UART(addrUART[cycle],INT_IRQ_ALL_OFF);
       }
       VPICD_Physically_Mask(hIRQ);
       VPICD_Force_Default_Behavior(hIRQ);
    }
}

// Initializes UART
BYTE  CVXD_Init_UART(DWORD iobase)
{
    BYTE intstate;

    __asm
    {
       mov     edx,[iobase]
       mov     cx,[koefSpeed]
       add     dl,2
       mov     al,0x07
       out     dx,al
       in      al,dx
       and     al,0x40
       jnz     m0
       out     dx,al
    m0:add     dl,1
       mov     al,0x80
       out     dx,al
       sub     dl,3
       mov     al,cl
       out     dx,al
       add     dl,1
       mov     al,ch
       out     dx,al
       add     dl,2
       mov     al,[modeUART]
       out     dx,al
       sub     dl,3
       in      al,dx
       add     dl,4
       mov     al,0x0b
       out     dx,al
       sub     dl,3
       mov     al,0
       out     dx,al
       add     dl,4
       in      al,dx
       mov     [intstate],al
    }

    return(intstate);
}

//UART State
BYTE  CVXD_State_UART(DWORD iobase)
{
    BYTE intstate;
    __asm
    {
       mov     edx,[iobase]
       add     dl,5
       in      al,dx
       mov     [intstate],al
    }
    return(intstate);
}

// Transmits Symbol to UART
BYTE  CVXD_Transmit_UART(DWORD iobase, BYTE sym)
{
    BYTE intstate;
    __asm
    {
       mov     edx,[iobase]
       add     dl,5
       in      al,dx
       mov     [intstate],al
       test    al,0x20
       jz      m0
       mov     al,[sym]
       sub     dl,5
       out     dx,al
    m0:
    }
    return(intstate);
}

// Receives Symbol from UART
BYTE  CVXD_Receive_UART(DWORD iobase, PBYTE sym)
{
    BYTE intstate, symbol;
    symbol = 0;
    __asm
    {
       mov     edx,[iobase]
       add     dl,5
       in      al,dx
       mov     [intstate],al
       test    al,0x01
       jz      m0
       sub     dl,5
       in      al,dx
       mov     [symbol],al
    m0:
    }
    *sym = symbol;
    return(intstate);
}

//Masks UART IRQs
VOID  CVXD_Mask_UART(DWORD iobase, BYTE mask)
{
    __asm
    {
       mov     edx,[iobase]
       add     dl,1
       mov     al,[mask]
       out     dx,al
    }
}

// Is UART IRQs?
BOOL  CVXD_Is_UART_IRQs(DWORD iobase, PBYTE require)
{
    BYTE req;
    __asm
    {
       mov     edx,[iobase]
       add     dl,2
       in      al,dx
       mov     [req],al
    }
    *require = (req & 6);
    return((req & 1) == 0);
}

//Controls Multiplexsor
VOID  CVXD_Set_Multiplexsor(BYTE key)
{
    multiplexor = multiplexor & clearMx[cycles][key/points[cycles]] | accessMx[cycles][key];

    __asm
    {
      cli
      mov    edx,[addrMx]
      mov    al,[multiplexor]
      out    dx,al
    m0:  sti
    }
}

//Initialize Multiplexsor
VOID  CVXD_Init_Multiplexsor(void)
{
    __asm
    {
       cli
       mov    edx,[addrMx]
       mov    al,0x5A
       out    dx,al
       in     al,dx
       and    al,0x3F
       mov    ah,al
       mov    al,0xA5
       out    dx,al
       in     al,dx
       and    al,0x3F
       cmp    ax,0x1A25
       jne    m0
       mov    [koefSpeed],46
    m0:sti
    }
}

#pragma VxD_ICODE_SEG
#pragma VxD_IDATA_SEG

//Dispatch IOCTL Event SYS_DYNAMIC_DEVICE_INIT
DWORD _stdcall CVXD_Dynamic_Init(void)
{
    //Out_Debug_String("CONPHONE: Dynamic Init\n\r");
    return(VXD_SUCCESS);
}



