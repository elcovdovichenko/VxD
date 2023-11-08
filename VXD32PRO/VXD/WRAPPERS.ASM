;****************************************************************************
;                                                                           *
; THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY     *
; KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE       *
; IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR     *
; PURPOSE.                                                                  *
;                                                                           *
; Copyright 1993-95  Microsoft Corporation.  All Rights Reserved.           *
;                                                                           *
;****************************************************************************

include local.inc

StartCDecl Get_VM_Exec_Time@4

        mov ebx, [esp+4] ; Get hVM
        VxDCall Get_VM_Exec_Time
        ret 4

EndCDecl Get_VM_Exec_Time@4

StartCDecl Get_System_Time

        VxDCall Get_System_Time
        ret

EndCDecl Get_System_Time

END



