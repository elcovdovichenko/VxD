
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

#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG

//------------------ VXD GLOBAL VARIABLES -----------------------------------

//Post_Message mechanism
ULONG hWindow;
DWORD wm_Message;

// IRQ Control
BYTE nIRQ = 11;                                  // IRQ Number
HIRQ hIRQ = 0;                                   // IRQ Handle
VID IRQDesc;                                     // VPCID_IRQ_Descriptor
DWORD sIRQ;                                      // IRQ Status

//Control
DWORD addrRg = 0x360;                            // register adress
HTIMEOUT hTimeOut = 0;                           // timeOut handler
BYTE StateShlief = 1;                            // shlief state
BOOL Shlief = FALSE;                             // shlief existance

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
VOID  CVXD_Start_TimeOut(void);
VOID  CVXD_Stop_TimeOut(void);
HIRQ  CVXD_Hook_Irq(void);
VOID  CVXD_Reset_Irq(void);
VOID  CVXD_Set_Control(BYTE key);
BYTE  CVXD_Get_State(void);

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
    addrRg = pdwi[1];                            //
    hWindow = pdwi[2];                           //
    wm_Message = pdwi[3];                        //

    hIRQ = CVXD_Hook_Irq();                      //
    sIRQ = VPICD_Get_IRQ_Complete_Status(nIRQ);  //
    CVXD_Start_TimeOut();                        //
    StateShlief = CVXD_Get_State();              //

    pdwo[0] = hIRQ;                              //
    pdwo[1] = sIRQ;                              //

    return(NO_ERROR);
}

// Line Control
DWORD _stdcall CVXD_W32_Proc2(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwi;
    BYTE key;

    //Out_Debug_String("CONPHONE: CVXD_W32_Proc2\n\r");

    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    key = pdwi[0];
    CVXD_Set_Control(key);

    return(NO_ERROR);
}

//Reset Timeout and Interrupt
DWORD _stdcall CVXD_W32_Proc3(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    CVXD_Stop_TimeOut();
    CVXD_Reset_Irq();
    hIRQ = 0;

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
    BYTE state;

    __asm
    {
       cli
       pushad
    }

    state = CVXD_Get_State();
    state = (state >> 1) & 0xF;
    _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, state, 0, NULL, 0);

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
    StateShlief = CVXD_Get_State();
    //_SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, StateShlief, 0, NULL, 0);

    if (((StateShlief & 1) != 0) && Shlief)
    {
       Shlief = FALSE;
      _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, 0, 0, NULL, 0);
    }
    else
    {
      if (((StateShlief & 1) == 0) && !Shlief)
      {
         Shlief = TRUE;
        _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message, 0xF, 0, NULL, 0);
      }
    }

    CVXD_Start_TimeOut();
}

// Start TimeOut
VOID  CVXD_Start_TimeOut(void)
{
    if (hTimeOut != 0) Cancel_Time_Out(hTimeOut);
    hTimeOut = Set_Async_Time_Out(&CVXD_Time_Int, 100, 0);
}

// Stop TimeOut
VOID  CVXD_Stop_TimeOut(void)
{
    if (hTimeOut != 0) Cancel_Time_Out(hTimeOut);
    hTimeOut = 0;
}

//Hooks definite IRQ
HIRQ  CVXD_Hook_Irq(void)
{
    HIRQ handle;

    IRQDesc.VID_IRQ_Number = nIRQ;
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
    if (hIRQ != 0)
    {
       VPICD_Physically_Mask(hIRQ);
       VPICD_Force_Default_Behavior(hIRQ);
    }
}

//Set Control Register
VOID  CVXD_Set_Control(BYTE key)
{
    __asm
    {
      mov    edx,[addrRg]
      mov    al,[key]
      out    dx,al
    }
}

//Get State Register
BYTE  CVXD_Get_State(void)
{
    BYTE state;
    __asm
    {
       mov     edx,[addrRg]
       in      al,dx
       mov     [state],al
    }
    return(state);
}

#pragma VxD_ICODE_SEG
#pragma VxD_IDATA_SEG

//Dispatch IOCTL Event SYS_DYNAMIC_DEVICE_INIT
DWORD _stdcall CVXD_Dynamic_Init(void)
{
    //Out_Debug_String("CONPHONE: Dynamic Init\n\r");
    return(VXD_SUCCESS);
}
