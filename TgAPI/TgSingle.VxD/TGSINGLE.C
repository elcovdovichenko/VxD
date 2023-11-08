
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

//------------------ VXD GLOBAL CONSTANTS -----------------------------------
// Количество каналов
#define CHANNELS 1

// Количество скоростей
#define SPEEDS 9

//Управление прерываниями
#define INT_IRQ_ALL_OFF 0         // Отключить все прерывания
#define INT_IRQ_RECEIVE_ON 1      // Включить прерывания приема
#define INT_IRQ_TRANSMIT_ON 2     // Включить прерывания передачи
#define INT_IRQ_ERROR_ON 4        // Включить прерывания по обрыву и ошибке
#define INT_IRQ_CHANGE_ON 8       // Включить прерывания по изменению линии

//Сообщения
#define MES_OUTPUT_DATA 1         // Передача буфера данных завершена
#define MES_OUTPUT_SYMBOL 2       // Передан очередной символ
#define MES_INPUT_SYMBOL 3        // Принят очередой символ
#define MES_LINE_CHANGE 4         // Принят сигнал указанной полярности и длительности
#define MES_LINE_IN 5             // Принят сигнал указанной полярности и длительности
#define MES_PULSE_IN 6            // Принят импульс указанной полярности и длительности
#define MES_PULSE_OUT 7           // Передан импульс указанной полярности и длительности
#define MES_ALARM_STATE 8         // Изменилось состояние индикатора аварии

//Коды завершения
#define EC_OK 0                   // Норма
#define EC_NOFUNC 1               // Функция не поддерживается
#define EC_WRONGNUM 2             // Недопустимый номер точки
#define EC_NOCTLNUM 3             // Точка с указанным номером аппаратно не поддерживается
#define EC_NOINITNUM 4            // Точка с указанным номером не инициирована
#define EC_WRONGPARAM 5           // Недопустимое значение параметра
#define EC_ABSENTBUF 6            // Буфер отсутствует
#define EC_OVERLAPBUF 7           // Перекрытие буферов

//
#define MEMORY_PARAGRAPH 16;

//------------------ SEGMENT'S DETERMINATION --------------------------------

#pragma VxD_LOCKED_CODE_SEG
#pragma VxD_LOCKED_DATA_SEG

//------------------ VXD GLOBAL VARIABLES -----------------------------------

//Post_Message mechanism
ULONG hWindow;                                     //Обработчик сообщений
DWORD wm_Message;                                  //Базовый номер сообщения

// IRQ Control
BYTE nIRQ = 3;                                     // IRQ Number
HIRQ hIRQ = 0;                                     // IRQ Handle
VID IRQDesc;                                       // VPCID_IRQ_Descriptor
DWORD sIRQ = 0;                                    // IRQ Status

//UART Control
DWORD addrUART = 0x2F8;                            // UART base address
WORD koefSpeed[SPEEDS] =
       {2304,1152,576,384,192,96,48,24,12};       // speed koefficients
struct structureState {                            // UART's state structure
     BOOL initInt;                                 // UART is init
     BYTE modeInt;                                 // UART's mode
     BYTE stateInt;                                // UART's state
     BYTE stateLine;                               // line state
     DWORD timeChange;                             // time line change
} State = {0,0,0,0,0};
struct structureTrasmit {                          // transmit buffer structure
     BYTE *pBuf;                                   // transmit buffer pointer
     ULONG size;                                   // transmit buffer size
     ULONG fill;                                   // transmit buffer fill
     ULONG count;                                  // transmit counters
} Transmit = {0,0,0,0};
struct structureLine {                             // line state structure
     BOOL polarity;                                // polarity
     ULONG interval;                               // interval
} Line = {0,0};
struct structurePulse {                            // pulse state structure
     BOOL polarity;                                // polarity
     ULONG intmin;                                 // min interval
     ULONG intmax;                                 // max interval
} Pulse = {0,0,0};
WORD trapFlags = 0;                                // channel's trap flags
WORD messageFlags = 0;                             // channel's message flags
BYTE existInt = 0;                                 // UART is existing
HTIMEOUT hTimeState = 0;                           // state timeout handlers
HTIMEOUT hTimePulse = 0;                           // pulse timeout handlers

//Маска изменения линии и уровня на линии
BYTE LINE_CHANGE = 0x2;
BYTE LINE_LEVEL = 0x20;

//Флажки состояния отслеживания
WORD F_WAIT_LINE = 1;                              // Ожидание изменения линии
WORD F_WAIT_PULSE = 2;                             // Ожидание импульса

//Флажки оповещения о состоянии линии
WORD F_STATE_START = 1;                            // Оповещение о переходе в старт
WORD F_STATE_STOP = 2;                             // Оповещение о переходе в стоп
WORD F_SYMBOL_OUT = 4;                             // Оповещение о передаче символа

//---------------------- VxD CALLs ------------------------------------------

DWORD _stdcall CVXD_W32_DeviceIOControl(DWORD, DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_CleanUp(void);
DWORD _stdcall CVXD_W32_Proc01(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc02(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc03(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc04(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc05(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc06(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc07(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc08(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc09(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc10(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc11(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc12(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc13(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc14(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc15(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc16(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc17(DWORD, DWORD, LPDIOC);
DWORD _stdcall CVXD_W32_Proc18(DWORD, DWORD, LPDIOC);
DWORD ( _stdcall *CVxD_W32_Proc[] )(DWORD, DWORD, LPDIOC) = {
        CVXD_W32_Proc01,  // Инициализация адаптера
        CVXD_W32_Proc02,  // Установить параметры обмена в канале
        CVXD_W32_Proc03,  // Установить режим приема в канале
        CVXD_W32_Proc04,  // Прекратить прием из канала
        CVXD_W32_Proc05,  // Выделить каналу буфер передачи указанного размера
        CVXD_W32_Proc06,  // Передать в канал буфер данных
        CVXD_W32_Proc07,  // Передать в канал один символ
        CVXD_W32_Proc08,  // Прекратить передачу в канал
        CVXD_W32_Proc09,  // Установить выходной сигнал указанной полярности в канале
        CVXD_W32_Proc10,  // Передать импульс в канал
        CVXD_W32_Proc11,  // Принять сигнал указанной полярности и длительности
        CVXD_W32_Proc12,  // Принять импульс указанной полярности и длительности
        CVXD_W32_Proc13,  // Прекратить отслеживание входного сигнала
        CVXD_W32_Proc14,  // Текущее состояние линии
        CVXD_W32_Proc15,  // Режим оповещения о состоянии линии
        CVXD_W32_Proc16,  // Режим оповещения об аварии линии
        CVXD_W32_Proc17,  // Отключить канал
        CVXD_W32_Proc18}; // Управление сигнализацией
#define MAX_CVXD_W32_API (sizeof(CVxD_W32_Proc)/sizeof(DWORD))

//-------------- Vxd Declared Functions -------------------------------------

HIRQ  CVXD_Hook_Irq(void);
VOID  CVXD_Reset_Irq(void);
VOID  CVXD_Hw_Int(void);
BOOL  CVXD_Is_UART_IRQs(PBYTE require);
VOID  CVXD_Init_UART(void);
BYTE  CVXD_Mode_UART(WORD koef, BYTE mode);
VOID  CVXD_Mask_UART(BYTE mask);
VOID  CVXD_Set_IRQ_UART(BYTE mask);
VOID  CVXD_Reset_IRQ_UART(BYTE mask);
BYTE  CVXD_Transmit_UART(BYTE sym);
BYTE  CVXD_Receive_UART(PBYTE sym);
BYTE  CVXD_Get_Line_UART(void);
VOID  CVXD_Set_Line_UART(BOOL start);
VOID  CVXD_Invert_Line_UART(void);
VOID  CVXD_Time_Pulse(void);
VOID  CVXD_Start_TimePulse(DWORD Time);
VOID  CVXD_Stop_TimePulse(void);
VOID  CVXD_Time_State(void);
VOID  CVXD_Start_TimeState(DWORD Time);
VOID  CVXD_Stop_TimeState(void);
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

    // DIOC_OPEN is sent when VxD is loaded by CreateFile
    //  (this happens just after SYS_DYNAMIC_INIT)
    if ( dwService == DIOC_OPEN )
    {
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

// Инициализация адаптера
DWORD _stdcall CVXD_W32_Proc01(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    addrUART = pdwi[0];                          //
    nIRQ = pdwi[1];                              //
    hWindow = pdwi[2];                           //
    wm_Message = pdwi[3];                        //

    hIRQ = CVXD_Hook_Irq();                      //
    sIRQ = VPICD_Get_IRQ_Complete_Status(nIRQ);  //
    if (hIRQ != 0) CVXD_Init_UART();             //

    pdwo[0] = hIRQ;                              //
    pdwo[1] = sIRQ;                              //
    pdwo[2] = CHANNELS;
    pdwo[3] = &existInt;
    pdwo[4] = CVXD_IRQ_Mask();
    pdwo[5] = 0;

    return(NO_ERROR);
}

// Установить параметры обмена в канале
DWORD _stdcall CVXD_W32_Proc02(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel, speed, databits, stopbits;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //
    speed = pdwi[1];                             //
    databits = pdwi[2]-5;                        //
    stopbits = pdwi[3]-1;                        //

    if (channel < CHANNELS)
    {
      if ((speed < SPEEDS) && (databits < 4) && (stopbits < 2))
      {
        State.modeInt = (stopbits << 2) | databits;
        State.stateInt = CVXD_Mode_UART(koefSpeed[speed],State.modeInt);
        State.stateLine = CVXD_Get_Line_UART();
        State.timeChange = Get_System_Time();

        if ((State.stateInt & 0x60) != 0)
        {
          State.initInt = TRUE;
          pdwo[0] = EC_OK;
        }
        else
        {
          State.initInt = FALSE;
          pdwo[0] = EC_NOCTLNUM;
        }

        pdwo[1] = State.stateInt;
        pdwo[2] = State.timeChange;
      }
      else
        pdwo[0] = EC_WRONGPARAM;               //
    }
    else
      pdwo[0] = EC_WRONGNUM;                   //

    return(NO_ERROR);
}

// Установить режим приема в канале
DWORD _stdcall CVXD_W32_Proc03(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        CVXD_Set_IRQ_UART(INT_IRQ_RECEIVE_ON);
        pdwo[0] = EC_OK;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;                   //

    return(NO_ERROR);
}

// Прекратить прием из канала
DWORD _stdcall CVXD_W32_Proc04(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        CVXD_Reset_IRQ_UART(INT_IRQ_RECEIVE_ON);
        pdwo[0] = EC_OK;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;                   //

    return(NO_ERROR);
}

// Выделить каналу буфер передачи указанного размера
DWORD _stdcall CVXD_W32_Proc05(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;
    DWORD sizebuf;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //
    sizebuf = pdwi[1];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        if (Transmit.pBuf == 0)
        {
          if (sizebuf > 0)
          {
            Transmit.size = sizebuf;
            Transmit.pBuf = _HeapAllocate(Transmit.size,0);
            if (Transmit.size != 0)
            {
              Transmit.fill = 0;
              Transmit.count = 0;
              pdwo[0] = EC_OK;
              pdwo[1] = Transmit.pBuf;
            }
            else
              pdwo[0] = EC_ABSENTBUF;
          }
          else
            pdwo[0] = EC_ABSENTBUF;
        }
        else
          pdwo[0] = EC_OVERLAPBUF;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Передать в канал буфер данных
DWORD _stdcall CVXD_W32_Proc06(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;
    DWORD fillbuf;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //
    fillbuf = pdwi[1];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        if (Transmit.pBuf != 0)
        {
          if (Transmit.fill == 0)
          {
            pdwo[0] = EC_OK;
            if (fillbuf > 0)
            {
              Transmit.fill = fillbuf;
              Transmit.count = 0;
              State.stateInt = CVXD_Transmit_UART(*(Transmit.pBuf));
              CVXD_Set_IRQ_UART(INT_IRQ_TRANSMIT_ON);
            }
          }
          else
            pdwo[0] = EC_OVERLAPBUF;
        }
        else
          pdwo[0] = EC_ABSENTBUF;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Передать в канал один символ
DWORD _stdcall CVXD_W32_Proc07(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel, symbol;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //
    symbol = pdwi[1];                            //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        pdwo[0] = EC_OK;
        if (Transmit.pBuf == 0)
        {
          Transmit.size = MEMORY_PARAGRAPH;
          Transmit.pBuf = _HeapAllocate(Transmit.size,0);
          if (Transmit.size != 0)
          {
            Transmit.fill = 1;
            Transmit.count = 0;
            *(Transmit.pBuf) = symbol;
            State.stateInt = CVXD_Transmit_UART(*(Transmit.pBuf));
            CVXD_Set_IRQ_UART(INT_IRQ_TRANSMIT_ON);
          }
          else
            pdwo[0] = EC_ABSENTBUF;
        }
        else
        {
          if (Transmit.fill == Transmit.size)
          {
            Transmit.size = Transmit.size + MEMORY_PARAGRAPH;
            Transmit.pBuf = _HeapReAllocate(Transmit.pBuf,Transmit.size,0);
          }
          *(Transmit.pBuf+Transmit.fill) = symbol;
          Transmit.fill++;
        }
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Прекратить передачу в канал
DWORD _stdcall CVXD_W32_Proc08(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        CVXD_Reset_IRQ_UART(INT_IRQ_TRANSMIT_ON);
        if (Transmit.pBuf != 0) _HeapFree(Transmit.pBuf,0);
        Transmit.pBuf = 0;
        pdwo[0] = EC_OK;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;                   //


    return(NO_ERROR);
}

// Установить выходной сигнал указанной полярности в канале
DWORD _stdcall CVXD_W32_Proc09(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;
    BOOL start;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //
    start = pdwi[1];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        CVXD_Reset_IRQ_UART(INT_IRQ_TRANSMIT_ON);
        if (Transmit.pBuf != 0) _HeapFree(Transmit.pBuf,0);
        Transmit.pBuf = 0;
        CVXD_Set_Line_UART(start);
        pdwo[0] = EC_OK;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Передать импульс в канал
DWORD _stdcall CVXD_W32_Proc10(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;
    BOOL start;
    DWORD time;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //
    start = pdwi[1];                           //
    time = pdwi[2];                            //


    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        CVXD_Reset_IRQ_UART(INT_IRQ_TRANSMIT_ON);
        if (Transmit.pBuf != 0) _HeapFree(Transmit.pBuf,0);
        Transmit.pBuf = 0;
        CVXD_Set_Line_UART(start);
        CVXD_Start_TimePulse(time);
        pdwo[0] = EC_OK;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Принять сигнал указанной полярности и длительности
DWORD _stdcall CVXD_W32_Proc11(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;
    ULONG res;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        Line.polarity = pdwi[1];
        Line.interval = pdwi[2];
        trapFlags = trapFlags | F_WAIT_LINE;

        if (Line.interval > 0)
        {
          if ((((State.stateLine & LINE_LEVEL) == LINE_LEVEL) && Line.polarity)
              || (((State.stateLine & LINE_LEVEL) == 0) && !Line.polarity))
            CVXD_Start_TimeState(Line.interval);
          else
            CVXD_Stop_TimeState();
        }
        else
        {
          if ((((State.stateLine & LINE_LEVEL) == LINE_LEVEL) && Line.polarity)
            || (((State.stateLine & LINE_LEVEL) == 0) && !Line.polarity))
          {
            res = Get_System_Time();
            res = res - State.timeChange;
            _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_LINE_IN, 0, res, NULL, 0);
          }
          CVXD_Stop_TimeState();
        }

        pdwo[0] = EC_OK;
        pdwo[1] = trapFlags;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Принять импульс указанной полярности и длительности
DWORD _stdcall CVXD_W32_Proc12(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        Pulse.polarity = pdwi[1];
        Pulse.intmin = pdwi[2];
        Pulse.intmax = pdwi[3];
        if (Pulse.intmax > Pulse.intmin)
        {
          trapFlags = trapFlags | F_WAIT_PULSE;

          pdwo[0] = EC_OK;
          pdwo[1] = trapFlags;
        }
        else
          pdwo[0] = EC_WRONGPARAM;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Прекратить отслеживание входного сигнала
DWORD _stdcall CVXD_W32_Proc13(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel, flags;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //
    flags = pdwi[1];                           //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        CVXD_Stop_TimeState();
        trapFlags = trapFlags & ~flags;

        pdwo[0] = EC_OK;
        pdwo[1] = trapFlags;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Текущее состояние линии
DWORD _stdcall CVXD_W32_Proc14(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        pdwo[0] = EC_OK;
        pdwo[1] = ((State.stateLine & LINE_LEVEL) == LINE_LEVEL);
        pdwo[2] = State.timeChange;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Режим оповещения о состоянии линии
DWORD _stdcall CVXD_W32_Proc15(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;
    WORD mode;
    BOOL action;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //
    mode = pdwi[1];
    action = pdwi[2];

    if (channel < CHANNELS)
    {
      if (State.initInt)
      {
        if (action)
        {
          messageFlags = messageFlags | mode;
        }
        else
        {
          messageFlags = messageFlags & ~mode;
        }
        pdwo[0] = EC_OK;
      }
      else
        pdwo[0] = EC_NOINITNUM;                   //
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Режим оповещения об аварии линии
DWORD _stdcall CVXD_W32_Proc16(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;

    pdwo[0] = EC_NOFUNC;

    return(NO_ERROR);
}

// Отключить канал
DWORD _stdcall CVXD_W32_Proc17(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo, pdwi;
    BYTE channel;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;
    pdwi = (PDWORD)lpDIOCParms->lpvInBuffer;

    channel = pdwi[0];                         //

    if (channel < CHANNELS)
    {
      CVXD_Stop_TimeState();
      CVXD_Stop_TimePulse();
      CVXD_Set_IRQ_UART(INT_IRQ_ALL_OFF);
      CVXD_Set_Line_UART(TRUE);
      if (Transmit.pBuf != 0) _HeapFree(Transmit.pBuf,0);
      State.initInt = FALSE;
      Transmit.pBuf = 0;
      messageFlags = 0;
      trapFlags = 0;
      pdwo[0] = EC_OK;
    }
    else
      pdwo[0] = EC_WRONGNUM;

    return(NO_ERROR);
}

// Управление сигнализацией
DWORD _stdcall CVXD_W32_Proc18(DWORD dwDDB, DWORD hDevice, LPDIOC lpDIOCParms)
{
    PDWORD pdwo;

    pdwo = (PDWORD)lpDIOCParms->lpvOutBuffer;

    pdwo[0] = EC_NOFUNC;

    return(NO_ERROR);
}

// Dispatch IOCTL Event SYS_DYNAMIC_DEVICE_EXIT
DWORD _stdcall CVXD_Dynamic_Exit(void)
{
    return(VXD_SUCCESS);
}

// Dispatch IOCTL Event DIOC_CLOSEHANDLE
DWORD _stdcall CVXD_CleanUp(void)
{
    CVXD_Reset_Irq();
    return(VXD_SUCCESS);
}

//---------------------- FUNCTIONS ------------------------------------------

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
    if (hIRQ != 0)
    {
       CVXD_Mask_UART(INT_IRQ_ALL_OFF);
       VPICD_Physically_Mask(hIRQ);
       VPICD_Force_Default_Behavior(hIRQ);
       hIRQ = 0;
    }
}

// Intrrupt Handler
VOID  CVXD_Hw_Int(void)
{
    BYTE  req, rInt, sym;
    DWORD res;
    ULONG now, interval;

    __asm
    {
       pushad
    }

     while (TRUE)
     {

       if (!CVXD_Is_UART_IRQs(&req)) break;

       switch(req)
       {
       case 0: // Change line state
         now = Get_System_Time();
         State.stateLine = CVXD_Get_Line_UART();

         if ((State.stateLine & LINE_CHANGE) != 0)
         {
           interval = now - State.timeChange;
           State.timeChange = now;
           // wait change line?
           if ((trapFlags & F_WAIT_LINE) == F_WAIT_LINE)
           {
             if (Line.interval > 0)
             {
               if ((((State.stateLine & LINE_LEVEL) == LINE_LEVEL) && Line.polarity)
                 || (((State.stateLine & LINE_LEVEL) == 0) && !Line.polarity))
                 CVXD_Start_TimeState(Line.interval);
               else
                 CVXD_Stop_TimeState();
             }
             else
             {
               _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_LINE_IN, 0, interval, NULL, 0);
               CVXD_Stop_TimeState();
             }
           }
           // wait pulse?
           if (((trapFlags & F_WAIT_PULSE) == F_WAIT_PULSE)
             && (interval >= Pulse.intmin) && (interval <= Pulse.intmax)
               && ((((State.stateLine & LINE_LEVEL) == LINE_LEVEL) && !Pulse.polarity)
                 || (((State.stateLine & LINE_LEVEL) == 0) && Pulse.polarity)))
           {
             _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_PULSE_IN, 0, interval, NULL, 0);
           }
           // signal change line?
           if (((messageFlags & F_STATE_START) == F_STATE_START)
               && ((State.stateLine & LINE_LEVEL) == LINE_LEVEL) ||
               ((messageFlags & F_STATE_STOP) == F_STATE_STOP)
               && ((State.stateLine & LINE_LEVEL) == 0))
             {
             _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_LINE_CHANGE, 0, now, NULL, 0);
             }
         }
         break;
       case 2: // Transmit the symbol
         if ((messageFlags & F_SYMBOL_OUT) == F_SYMBOL_OUT)
         {
           sym = *(Transmit.pBuf+Transmit.count);
           _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_OUTPUT_SYMBOL, 0, sym, NULL, 0);
         }
         Transmit.count++;
         if (Transmit.fill > Transmit.count)
         {
           sym = *(Transmit.pBuf+Transmit.count);
           State.stateInt = CVXD_Transmit_UART(sym);
         }
         else
         {
           _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_OUTPUT_DATA, 0, 0, NULL, 0);
           CVXD_Reset_IRQ_UART(INT_IRQ_TRANSMIT_ON);
           if (Transmit.pBuf != 0) _HeapFree(Transmit.pBuf,0);
           Transmit.pBuf = 0;
         }
         break;
       case 4: // Receive the symbol
         State.stateInt = CVXD_Receive_UART(&rInt);
         res = State.stateInt;
         res = (res << 8) + rInt;
         _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_INPUT_SYMBOL, 0, res, NULL, 0);
         break;
       }
     }

    VPICD_Phys_EOI(hIRQ);

    __asm
    {
       popad
    }
}

// Is UART IRQs?
BOOL  CVXD_Is_UART_IRQs(PBYTE require)
{
    BYTE req;
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,2
       in      al,dx
       mov     [req],al
       sti
    }
    *require = (req & 6);
    return((req & 1) == 0);
}

// Initializes UARTs Of Adapter
VOID  CVXD_Init_UART(void)
{
    BYTE intstate;

    __asm
    {
       cli
       mov     edx,[addrUART]
       mov     cx,2304
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
       mov     al,0x44
       out     dx,al
       sub     dl,3
       in      al,dx
       add     dl,4
       mov     al,0
       out     dx,al
       sub     dl,3
       mov     al,0
       out     dx,al
       add     dl,4
       in      al,dx
       mov     [intstate],al
       sti
    }
    State.stateInt = intstate;
    existInt = ((intstate & 0x60) != 0);
    State.initInt = FALSE;
}

// Initializes Determinated UART
BYTE  CVXD_Mode_UART(WORD koef, BYTE mode)
{
    BYTE intstate;

    __asm
    {
       cli
       mov     edx,[addrUART]
       mov     cx,[koef]
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
       mov     al,[mode]
       out     dx,al
       sub     dl,3
       in      al,dx
       add     dl,4
       mov     al,0x08
       out     dx,al
       sub     dl,3
       mov     al,0x08
       out     dx,al
       add     dl,4
       in      al,dx
       mov     [intstate],al
       sti
    }
    return(intstate);
}

//Masks UART IRQs
VOID  CVXD_Mask_UART(BYTE mask)
{
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,1
       mov     al,[mask]
       out     dx,al
       sti
    }
}

//Set UART IRQs
VOID  CVXD_Set_IRQ_UART(BYTE mask)
{
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,1
       in      al,dx
       or      al,[mask]
       out     dx,al
       sti
    }
}

//Reset UART IRQs
VOID  CVXD_Reset_IRQ_UART(BYTE mask)
{

    mask = ~mask;

    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,1
       in      al,dx
       and     al,[mask]
       out     dx,al
       sti
    }
}

// Transmits Symbol to UART
BYTE  CVXD_Transmit_UART(BYTE sym)
{
    BYTE intstate;
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,5
       in      al,dx
       mov     [intstate],al
       test    al,0x20
       jz      m0
       mov     al,[sym]
       sub     dl,5
       out     dx,al
    m0:sti
    }
    return(intstate);
}

// Receives Symbol from UART
BYTE  CVXD_Receive_UART(PBYTE sym)
{
    BYTE intstate, symbol;
    symbol = 0;
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,5
       in      al,dx
       mov     [intstate],al
       test    al,0x01
       jz      m0
       sub     dl,5
       in      al,dx
       mov     [symbol],al
    m0:sti
    }
    *sym = symbol;
    return(intstate);
}

// Get line state in UART
BYTE  CVXD_Get_Line_UART(void)
{
    BYTE state;
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,6
       in      al,dx
       mov     [state],al
       sti
    }
    return(state);
}

// Set line state in UART
VOID  CVXD_Set_Line_UART(BOOL start)
{
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,3
       in      al,dx
       cmp     start,0                //start?
       je      m0                     //no
       or      al,40h                 //polatity = start
       jmp     m1
    m0:and     al,0BFh                //polatity = stop
    m1:out     dx,al
       sti
    }
}

// Invert line state in UART
VOID  CVXD_Invert_Line_UART(void)
{
    __asm
    {
       cli
       mov     edx,[addrUART]
       add     dl,3
       in      al,dx
       xor     al,40h                 //invert polarity
       out     dx,al
       sti
    }
}

//Pulse Timeing
VOID  CVXD_Time_Pulse(void)
{
    CVXD_Invert_Line_UART();
    CVXD_Stop_TimePulse();
    _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_PULSE_OUT, 0, 0, NULL, 0);
}

// Start TimePulse
VOID  CVXD_Start_TimePulse(DWORD Time)
{
    if (hTimePulse != 0) Cancel_Time_Out(hTimePulse);
    hTimePulse = Set_Async_Time_Out(&CVXD_Time_Pulse, Time, 0);
}

// Stop TimePulse
VOID  CVXD_Stop_TimePulse(void)
{
    if (hTimePulse != 0) Cancel_Time_Out(hTimePulse);
    hTimePulse = 0;
}

//LineState Timeing
VOID  CVXD_Time_State(void)
{
    ULONG res;

    CVXD_Stop_TimeState();
    res = Get_System_Time();
    res = (res - State.timeChange);
    _SHELL_PostMessage(hWindow, SPM_UM_AlwaysSchedule+wm_Message+MES_LINE_IN, 0, res, NULL, 0);
}

// Start TimeState
VOID  CVXD_Start_TimeState(DWORD Time)
{
    if (hTimeState != 0) Cancel_Time_Out(hTimeState);
    hTimeState = Set_Async_Time_Out(&CVXD_Time_State, Time, 0);
}

// Stop TimeState
VOID  CVXD_Stop_TimeState(void)
{
    if (hTimeState != 0) Cancel_Time_Out(hTimeState);
    hTimeState = 0;
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

//---------------- INITIALISATION SEGMENT'S DETERMINATION -------------------

#pragma VxD_ICODE_SEG
#pragma VxD_IDATA_SEG

//Dispatch IOCTL Event SYS_DYNAMIC_DEVICE_INIT
DWORD _stdcall CVXD_Dynamic_Init(void)
{
    return(VXD_SUCCESS);
}

//--------------------- THE END ---------------------------------------------
