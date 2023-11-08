
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





    return(NO_ERROR);
}

// Start transmision
DWORD _stdcall CVXD_W32_Proc2(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwi;
    BYTE key, cycle;

    //Out_Debug_String("CONPHONE: CVXD_W32_Proc2\n\r");

    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;



    return(NO_ERROR);
}

//Reset Timeouts and Interrupt
DWORD _stdcall CVXD_W32_Proc3(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    BYTE cycle;



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


#pragma VxD_ICODE_SEG
#pragma VxD_IDATA_SEG

//Dispatch IOCTL Event SYS_DYNAMIC_DEVICE_INIT
DWORD _stdcall CVXD_Dynamic_Init(void)
{
    //Out_Debug_String("CONPHONE: Dynamic Init\n\r");
    return(VXD_SUCCESS);
}



