
#define WANTVXDWRAPS

#include <basedef.h>
#include <vmm.h>
#include <debug.h>
#include <vxdwraps.h>
#include <vwin32.h>
#include <winerror.h>
#include <vpicd.h>
#include <shell.h>

//------ …€‹ˆ‡€–ˆŸ ‚ WRAPPERS.ASM -----------------------------
//MAKE_HEADER(DWORD,    _stdcall, Get_VM_Exec_Time, (HVM hvm))
//#define Get_VM_Exec_Time PREPEND(Get_VM_Exec_Time)
//MAKE_HEADER(DWORD,    _cdecl, Get_System_Time, (VOID))
//#define Get_System_Time PREPEND(Get_System_Time)
//----------------------------------------------------------------

#define CVXD_VERSION 0x400

typedef DIOCPARAMETERS *LPDIOC;

#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG

HVM hSysVM;
ULONG hWindow;
DWORD wm_Message;
HIRQ hIRQ = 0;
VID IRQDesc;
DWORD sIRQ;
BYTE sInt, rInt;
BYTE NumIRQ;
WORD Port_Base;
BYTE bufTransmit[80];
BYTE bufReceive[80];
BYTE *pTransmit;
BYTE *pReceive;
BYTE cTransmit, sizeReceive;
HTIMEOUT hTimeOut = 0, hTimePNN = 0;
BYTE pnnPhase = 0;

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

VOID  CVXD_Hw_Int(void);
VOID  CVXD_Time_Int(void);
VOID  CVXD_PNN_Int(void);
HIRQ  CVXD_Hook_Irq(WORD IRQNum);
VOID  CVXD_Reset_Irq(HIRQ handle);
BYTE  CVXD_Init_Port(DWORD IOBase);
BYTE  CVXD_Transmit_Port(DWORD IOBase, BYTE sym);
BYTE  CVXD_Receive_Port(DWORD IOBase, PBYTE sym);
VOID  CVXD_Mask_Port(DWORD IOBase);
BYTE  CVXD_IRQ_Mask(void);


/****************************************************************************
                  CVXD_W32_DeviceIOControl
****************************************************************************/
DWORD _stdcall CVXD_W32_DeviceIOControl(DWORD  dwService,
                                        DWORD  dwDDB,
                                        DWORD  hDevice,
                                        LPDIOC lpDIOCParms)
{
    DWORD dwRetVal = 0;

    // DIOC_OPEN is sent when VxD is loaded w/ CreateFile
    //  (this happens just after SYS_DYNAMIC_INIT)
    if ( dwService == DIOC_OPEN )
    {
        Out_Debug_String("CVXDSAMP: WIN32 DEVIOCTL supported here!\n\r");
        // Must return 0 to tell WIN32 that this VxD supports DEVIOCTL
        dwRetVal = hIRQ; //‡ é¨â  ®â ¯®¢â®à­®© § £àã§ª¨ VxD
    }
    // DIOC_CLOSEHANDLE is sent when VxD is unloaded w/ CloseHandle
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

DWORD _stdcall CVXD_W32_Proc1(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdw, pdw1;

    Out_Debug_String("CVXDSAMP: CVXD_W32_Proc1\n\r");

    pdw = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdw1 = (PDWORD)lpDIOCParms->lpvInBuffer;

    NumIRQ = pdw1[0];
    Port_Base = pdw1[1];
    hWindow = pdw1[2];
    wm_Message = pdw1[3];

    bufTransmit[0] = 0;
    bufReceive[0] = 0;
    pTransmit = bufTransmit;
    pReceive = bufReceive;
    sizeReceive = sizeof(bufReceive);

    hSysVM = Get_Sys_VM_Handle();
    hIRQ = CVXD_Hook_Irq(NumIRQ);
    sIRQ = VPICD_Get_IRQ_Complete_Status(NumIRQ);
    if (hIRQ != 0) sInt = CVXD_Init_Port(Port_Base);

    pdw[0] = hSysVM;
    pdw[1] = sIRQ;
    pdw[2] = hIRQ;
    pdw[3] = sInt;
    pdw[4] = CVXD_IRQ_Mask();
    pdw[5] = bufTransmit;
    pdw[6] = bufReceive;


    return(NO_ERROR);
}

DWORD _stdcall CVXD_W32_Proc2(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdw;
    DWORD IOBase;

    Out_Debug_String("CVXDSAMP: CVXD_W32_Proc2\n\r");

    pdw = (PDWORD)lpDIOCParms->lpvOutBuffer;

    IOBase = Port_Base;
    __asm
    {
       mov     edx,[IOBase]
       add     dl,3
       mov     al,4
       out     dx,al
    }

    if (*pTransmit > 0)
      {
      cTransmit = 1;
      sInt = CVXD_Transmit_Port(Port_Base, *(pTransmit+cTransmit));
      }

    *pdw = *pTransmit;
    pdw[1] = sInt;
    pdw[3] = Get_Last_Updated_System_Time();
    pdw[2] = Get_System_Time();

    return(NO_ERROR);
}

DWORD _stdcall CVXD_W32_Proc3(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    Out_Debug_String("CVXDSAMP: CVXD_W32_Proc3\n\r");

    if (pnnPhase == 0)
    {
       DWORD IOBase;
       IOBase = Port_Base;
       __asm
       {
          mov     edx,[IOBase]
          add     dl,3
          mov     al,0x40
          out     dx,al
       }
       hTimePNN = Set_Async_Time_Out(&CVXD_PNN_Int, 2000, 0);
       pnnPhase = 1;
    }

    return(NO_ERROR);
}

DWORD _stdcall CVXD_Dynamic_Exit(void)
{
    Out_Debug_String("CVXDSAMP: Dynamic Exit\n\r");
    return(VXD_SUCCESS);
}

DWORD _stdcall CVXD_CleanUp(void)
{
    Out_Debug_String("CVXDSAMP: Cleaning Up\n\r");

    CVXD_Reset_Irq(hIRQ);
    hIRQ = 0;

    return(VXD_SUCCESS);
}

VOID  CVXD_Hw_Int(void)
{
    while (TRUE)
    {
       BYTE req;
       DWORD IOBase;

       IOBase = Port_Base;
       __asm
       {
          mov     edx,[IOBase]
          add     dl,2
          in      al,dx
          mov     [req],al
       }
       if ((req & 1) != 0) break;
       switch(req & 6)
       {
       case 2:
         if (*pTransmit > cTransmit)
           {
           cTransmit++;
           sInt = CVXD_Transmit_Port(Port_Base, *(pTransmit+cTransmit));
           }
         break;
       case 4:
         sInt = CVXD_Receive_Port(Port_Base,&rInt);
         (*pReceive)++;
         if (*pReceive < sizeReceive)
           *(pReceive + (*pReceive)) = rInt;

         if (hTimeOut != 0) Cancel_Time_Out(hTimeOut);
         hTimeOut = Set_Async_Time_Out(&CVXD_Time_Int, 200, hTimeOut);

         break;
       }
    }

    VPICD_Phys_EOI(hIRQ);
}

VOID  CVXD_Time_Int(void)
{
    DWORD param;
    __asm
    {
       mov param,edx
    }

    if (*pReceive > 0)
      _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, param, 0, NULL, 0);

}

VOID  CVXD_PNN_Int(void)
{
    DWORD IOBase;
    IOBase = Port_Base;

    switch(pnnPhase)
    {
    case 1:
      if (hTimePNN != 0) Cancel_Time_Out(hTimePNN);
      hTimePNN = Set_Async_Time_Out(&CVXD_PNN_Int, 25, 0);
      __asm
      {
          mov     edx,[IOBase]
          add     dl,3
          mov     al,4
          out     dx,al
      }
      pnnPhase = 2;
      break;
    case 2:
      if (hTimePNN != 0) Cancel_Time_Out(hTimePNN);
      __asm
      {
          mov     edx,[IOBase]
          add     dl,3
          mov     al,0x40
          out     dx,al
      }
      pnnPhase = 0;
      break;
    }
}

HIRQ  CVXD_Hook_Irq(WORD IRQNum)
{
    HIRQ handle;

    IRQDesc.VID_IRQ_Number = IRQNum;
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

VOID  CVXD_Reset_Irq(HIRQ handle)
{
    if (handle != 0)
    {
       CVXD_Mask_Port(Port_Base);
       VPICD_Physically_Mask(handle);
       VPICD_Force_Default_Behavior(handle);
    }
}

BYTE  CVXD_Init_Port(DWORD IOBase)
{
    BYTE intstate;
    __asm
    {
       mov     edx,[IOBase]
       add     dl,3
       mov     al,0x80
       out     dx,al
       sub     dl,3
       mov     al,0x40
       out     dx,al
       add     dl,1
       mov     al,0x02
       out     dx,al
       add     dl,2
       mov     al,0x04
       out     dx,al
       sub     dl,3
       in      al,dx
       add     dl,4
       mov     al,0x0b
       out     dx,al
       sub     dl,3
       mov     al,0x03
       out     dx,al
       add     dl,4
       in      al,dx
       mov     [intstate],al
    }
    return(intstate);
}

BYTE  CVXD_Transmit_Port(DWORD IOBase, BYTE sym)
{
    BYTE intstate;
    __asm
    {
       mov     edx,[IOBase]
       add     dl,5
       in      al,dx
       mov     [intstate],al
       test    al,0x20
       jz      tp0
       mov     al,[sym]
       sub     dl,5
       out     dx,al
    tp0:
    }
    return(intstate);
}

BYTE  CVXD_Receive_Port(DWORD IOBase, PBYTE sym)
{
    BYTE intstate, symbol;
    symbol = 0;
    __asm
    {
       mov     edx,[IOBase]
       add     dl,5
       in      al,dx
       mov     [intstate],al
       test    al,0x01
       jz      tp0
       sub     dl,5
       in      al,dx
       mov     [symbol],al
    tp0:
    }
    *sym = symbol;
    return(intstate);
}

VOID  CVXD_Mask_Port(DWORD IOBase)
{
    __asm
    {
       mov     edx,[IOBase]
       add     dl,1
       mov     al,0
       out     dx,al
    }
}

BYTE  CVXD_IRQ_Mask(void)
{
    BYTE mask;
    __asm
    {
       mov      edx,0x21
       in       al,dx
       mov      [mask],al
    }
    return(mask);
}


#pragma VxD_ICODE_SEG
#pragma VxD_IDATA_SEG

DWORD _stdcall CVXD_Dynamic_Init(void)
{
    Out_Debug_String("CVXDSAMP: Dynamic Init\n\r");
    return(VXD_SUCCESS);
}



