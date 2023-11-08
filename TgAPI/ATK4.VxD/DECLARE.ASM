;****************************************************************************
PAGE 58,132
;****************************************************************************
TITLE CONTROL - ControlDispatch for VxD in C
;****************************************************************************

    .386p

;****************************************************************************
;                I N C L U D E S
;****************************************************************************

    .xlist
    include vmm.inc
    .list

; the following equate makes the VXD dynamically loadable.
ATK4_DYNAMIC EQU 1

;============================================================================
;        V I R T U A L   D E V I C E   D E C L A R A T I O N
;============================================================================

DECLARE_VIRTUAL_DEVICE  ATK4, 1, 0, CVXD_Control, UNDEFINED_DEVICE_ID,,,,

VxD_LOCKED_CODE_SEG

;============================================================================
;
;   PROCEDURE: CVXD_Control
;
;   DESCRIPTION:
;    Device control procedure for the CVXD VxD
;
;   ENTRY:
;    EAX = Control call ID
;
;   EXIT:
;    If carry clear then
;        Successful
;    else
;        Control call failed
;
;   USES:
;    EAX, EBX, ECX, EDX, ESI, EDI, Flags
;
;============================================================================

BeginProc CVXD_Control
    Control_Dispatch SYS_DYNAMIC_DEVICE_INIT, CVXD_Dynamic_Init, sCall
    Control_Dispatch SYS_DYNAMIC_DEVICE_EXIT, CVXD_Dynamic_Exit, sCall
    Control_Dispatch W32_DEVICEIOCONTROL,     CVXD_W32_DeviceIOControl, sCall, <ecx, ebx, edx, esi>
    clc
    ret
EndProc CVXD_Control


VxD_LOCKED_CODE_ENDS

    END

