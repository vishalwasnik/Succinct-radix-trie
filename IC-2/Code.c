#define _MAIN_C
#include <Intrins.h>
#include <Absacc.h>
#include <Stdio.h>  
#include ".\include\REG_MG82F6D17.H"
#include ".\include\Type.h"
#include ".\include\API_Macro_MG82F6D17.H"
#include ".\include\API_Uart_BRGRL_MG82F6D17.H"
extern void INIT_RAM_TABLE(void);
extern u8 Process_Incoming_Byte_Trie(u8 rx_byte);
volatile unsigned char current_identity = 0;
volatile unsigned int next_addr = 0;   // 16-bit
//volatile unsigned int next_addr = 0;
//extern code u8 Mask_Table[8]; // Assembly se Flash table ko link kiya

#define DICT_ADDR 0x3800  
#define MAX_SLOTS 32      
#define SPI_nSS P34
#define RX_BUF_SIZE 64      

sfr UARTSPICLK = 0xBB; 

// --- Global Variables ---
idata u8 uart_buf[50];    
u8 b_idx = 0;
idata u8 slot_data_buffer[16]; 

xdata u8 DMA_RxBuffer[RX_BUF_SIZE]; 
u8 last_read_idx = 0;    

// --- Trie State Machine Global Pointers ---
u16 current_node_idx = 0;   
u8 node_match_char_cnt = 0; 

u16 DMA_GetCurrentAddress(void) {
    u16 addr;
    u8 p_bak = SFRPI;     
    SFRPI = 4;            
    addr = ((u16)TH6 << 8) | TL6; 
    SFRPI = p_bak;        
    return addr;
}

// --- Function Prototypes ---
void IAP_WritePPage(u8 PsfrAddr, u8 PsfrData);
void Safe_IAP_Write(u16 addr, u8 *buf);
void Erase_Data_Page();
void Process_Data();
void Check_Serial();
void Dump_Dictionary();
void Send_To_IC3_Mode4(u16 attr_addr);        
u8 CharToHex(char c);

char putchar (char c) {        
    S0BUF = c;          
    while(TI0 == 0); 
    TI0 = 0;          
    return c;
}

u8 CharToHex(char c) {
    if (c >= '0' && c <= '9') return (c - '0');
    if (c >= 'A' && c <= 'F') return (c - 'A' + 10);
    if (c >= 'a' && c <= 'f') return (c - 'a' + 10);
    return 0;
}

void IAP_WritePPage(u8 PsfrAddr, u8 PsfrData) {
    u8 p_bak = SFRPI;
    SFRPI = 0x00;
    IFADRH = 0; 
    IFADRL = PsfrAddr;
    IFD = PsfrData;
    IFMT = 0x04; 
    ISPCR = 0x80;
    SCMD = 0x46; SCMD = 0xB9; 
    _nop_();
    ISPCR = 0;
    SFRPI = p_bak;
}

void Erase_Data_Page() {
    u8 p_bak = SFRPI;
    bit bEA = EA;
    printf("\n[SYSTEM] Erasing Dictionary...");
    IAP_WritePPage(0x11, (u8)(DICT_ADDR >> 8)); 
    EA = 0; 
    SFRPI = 0x00;
    IFMT = 0x03; 
    IFADRH = (u8)(DICT_ADDR >> 8);
    IFADRL = (u8)(DICT_ADDR & 0xFF);
    ISPCR = 0x80;
    SCMD = 0x46; SCMD = 0xB9; 
    _nop_();
    while(ISPCR & 0x01);
    ISPCR = 0x00; 
    IAP_WritePPage(0x11, 0x40); 
    SFRPI = p_bak; 
    EA = bEA;
    if(CBYTE[DICT_ADDR] == 0xFF) printf(" SUCCESS\n> ");
    else printf(" FAILED!\n> ");
}

void Safe_IAP_Write(u16 addr, u8 *buf) {
    u8 i, p_bak = SFRPI;
    u8 write_err = 0;
    bit bEA = EA;
    
    IAP_WritePPage(0x11, (u8)(DICT_ADDR >> 8)); 
    
    for(i = 0; i < 16; i++) { 
        EA = 0; 
        SFRPI = 0x00;
        IFMT = 0x02; 
        IFADRH = (u8)((addr + i) >> 8);
        IFADRL = (u8)((addr + i) & 0xFF);
        IFD = buf[i];
        ISPCR = 0x80; 
        SCMD = 0x46; SCMD = 0xB9; 
        _nop_();        
        while(ISPCR & 0x01); 
        if(CBYTE[addr + i] != buf[i]) write_err = 1;
        EA = bEA;
    }
    
    ISPCR = 0x00; 
    IAP_WritePPage(0x11, 0x40); 
    SFRPI = p_bak; 
    
    if(write_err) printf("\n[ERROR] Write Failed");
    else printf("\n[SUCCESS] Hex Data Saved in Slot: %bd", (u8)((addr - DICT_ADDR)/16));
    printf("\n> ");
}

void Send_To_IC3_Mode4(u16 attr_addr) {
    u8 p_bak = SFRPI;
    P34 = 0;           
    SFRPI = 1;         
    
    S1BUF = (u8)(attr_addr >> 8);          
    while(TI1 == 0); TI1 = 0;         
    
    S1BUF = (u8)(attr_addr & 0xFF);          
    while(TI1 == 0); TI1 = 0;         
    
    SFRPI = p_bak;     
    P34 = 1;           
}

void Process_Data(void) {
    u16 target = 0xFFFF;
    u8 slot, i = 0, h_idx = 0;
    idata u8 hex_converted[16]; 

    for(slot = 0; slot < 16; slot++) hex_converted[slot] = 0x00;

    while(i < b_idx && h_idx < 16) {
        if(uart_buf[i] == ' ') { 
            i++;
            continue;
        }
        hex_converted[h_idx++] = (CharToHex(uart_buf[i]) << 4) | CharToHex(uart_buf[i+1]);
        i += 2; 
    }

    if (h_idx > 0) {
        for(slot = 0; slot < MAX_SLOTS; slot++) {
            if(CBYTE[DICT_ADDR + (slot * 16)] == 0xFF) {
                target = DICT_ADDR + (slot * 16);
                break;
            }
        }
        if(target != 0xFFFF) Safe_IAP_Write(target, hex_converted);
        else printf("\n[LIMIT] MEMORY FULL\n> ");
    }
    b_idx = 0; 
}

void Dump_Dictionary(void) {
    u16 addr;
    u8 slot, i, val;
    printf("\n--- HEX DICTIONARY ---");
    for(slot = 0; slot < MAX_SLOTS; slot++) {
        addr = DICT_ADDR + (slot * 16);
        if(CBYTE[addr] != 0xFF) {
            printf("\nSlot [%02bd]: ", slot);
            for(i = 0; i < 16; i++) {
                val = CBYTE[addr + i];
                printf("%02X ", (u16)val);
            }
        }
    }
    printf("\n--- END ---\n> ");
}

void Check_Serial(void) {
    if (RI0) {
        u8 val = S0BUF;
        RI0 = 0;
        
        if (val == 'S' || val == 's') { 
            u8 current_write_idx = (DMA_GetCurrentAddress() - ((u16)&DMA_RxBuffer[0] & 0xFF)) % RX_BUF_SIZE;
            u8 pending = (current_write_idx >= last_read_idx) ? 
                         (current_write_idx - last_read_idx) : 
                         (RX_BUF_SIZE - last_read_idx + current_write_idx);
            
            printf("\n--- DMA STATUS ---");
            printf("\nPending Bytes: %bu", pending);
            printf("\nRead Index: %bu", last_read_idx);
            printf("\nWrite Index: %bu", current_write_idx);
            printf("\n> ");
            return; 
        }
				if (val == 'E' || val == 'e') { Erase_Data_Page(); return; }

        if (val == 'D' || val == 'd') { Dump_Dictionary(); return; }
        if (val == '\r' || val == '\n') {
            if (b_idx > 0) Process_Data();
            return;
        }
        if (b_idx < 48) { 
            uart_buf[b_idx++] = val;
            putchar(val); 
        }
    }
}

void Init_Slave_DMA_SPI_Simple(void) {
    DMA_Disable();
    SPI_Enable();
    SPI_SelectSLAVEByMSTRbit();
    SPI_SetCPOL_0(); 
    SPI_SetCPHA_1();
    SPI_SetDataMSB();
    SPI_SetUseP33P15P16P17(); 

    DMA_SetSource_SPI0RX();        
    DMA_SetDestination_XRAM();     
    
    DMA_SetXRAMStartaddr((u16)&DMA_RxBuffer[0]);
    DMA_SetCount(65536 - RX_BUF_SIZE); 
    
    DMA_EnLoop();              
    DMA_Enable();
    DMA_Start(); 
}

void InitSystem(void) {
    PORT_SetP3QuasiBi(BIT0|BIT1|BIT3|BIT5); 
    CLK_SetCKCON0(IHRCO_12MHz|CPUCLK_SYSCLK_DIV_1|SYSCLK_MCKDO_DIV_1);
    PORT_SetP1PushPull(BIT0 | BIT1 | BIT6);             
    PORT_SetP1OpenDrainPu(BIT5 | BIT7); 
    PORT_SetP3PushPull(BIT4);        
    PORT_SetP6OpenDrainPu(BIT1);     
    
    P11 = 1; 

    SFRPI = 1; 
    UART1_SetModeSPIMaster();           
    UART1_SetMISOP61();                 
    UART1_SetRxTxP10P11();              
    UART1_SetSPIClock_SYSCLKDiv12();     
    UART1_SetDataMSB();                 
    UARTSPICLK = 0x23;                  
    SFRPI = 0;

    UART0_SetAccess_S0CR1();
    UART0_SetMode8bitUARTVar();
    UART0_EnReception();
    UART0_SetBRGFromS0BRG();
    UART0_SetS0BRGBaudRateX2();
    UART0_SetS0BRGSelSYSCLK();
    UART0_SetS0BRGValue(S0BRG_BRGRL_9600_2X_12000000_1T);
    UART0_EnS0BRG();
    
    EA = 1;  
}

void main(void) {
    InitSystem();
    Init_Slave_DMA_SPI_Simple(); 
	  INIT_RAM_TABLE();
    printf("\n*** CONTINUOUS DMA SLAVE READY ***\n> ");

    while(1) {
        u8 current_write_idx = (DMA_GetCurrentAddress() - ((u16)&DMA_RxBuffer[0] & 0xFF)) % RX_BUF_SIZE;

        while (last_read_idx != current_write_idx) {
    u8 received_byte = DMA_RxBuffer[last_read_idx];
    
    // Function call ab status return karega
    if (Process_Incoming_Byte_Trie(received_byte) == 1) {
        printf("\n[DEBUG] Byte %02X: MATCH! Count: %bu", (u16)received_byte, node_match_char_cnt);
    } else {
        printf("\n[DEBUG] Byte %02X: NOT FOUND. Resetting to Root.", (u16)received_byte);
    }
    
    last_read_idx = (last_read_idx + 1) % RX_BUF_SIZE;
}

        Check_Serial(); 
    }
}
