#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdint.h>
#include <string.h>

//Returns index of inserted number. If number already exists in array, 
//doesn't add it a second time. Returns -1 if array is full and can't
//insert the val. If val is inserted, updates len automatically
int add2arr(int32_t *arr, int *len, int capacity, int val) {
    //See if val is already in arr. Who cares about speed??
    int i;
    for (i = 0; i < *len; i++) {
        if (arr[i] == val) return i;
    }
    
    //Value not found. Is there space for it?
    if (*len >= capacity) {
        return -1; //No room
    }
    
    //Insert at end of array
    arr[*len++] = val;
    return i;
}

//Returns number of bytes to skip. Always stops at NUL
int skip_ws_and_comments(char const* str) {
    char const *str_saved = str; //We'll subtract when we're done
    while(1) {
        if (*str == ';') {
            //Comment
            str++;
            //Read to end of line
            while (*str != '\n') str++;
        } else if (isspace(*str)) {
            str++;
        } else {
            break;
        }
    }
    
    return str - str_saved;
}

//Opcodes for each string the user can type
//Some of these are incomplete because they have fields that are filled in
//when the rest of the instruction is parsed
#define LD    0b00000000 /*LD/LDX use lower 3 bits to select source*/
#define LDX   0b00100000
#define ST    0b01000000
#define STX   0b01100000
#define IN    0b00000010
#define INX   0b00100010
#define OUT   0b00000000
#define OUTX  0b01110000
#define ADD   0b10000000 /*All ALU instructions use bit 4 to select X or IMM*/
#define SUB   0b10000001
#define XOR   0b10000010
#define OR	  0b10000011
#define AND   0b10000100
#define LSH   0b10000101
#define RSH   0b10000110
#define NOT   0b10000111
#define MUL   0b10001000
#define DIV   0b10001001
#define MOD   0b10001010
#define JA    0b10100000
#define JEQ   0b10100000
#define JGT   0b10100000
#define JGE   0b10100000
#define JSET  0b10100000
#define JLAST 0b10100000
#define TAX   0b11000000
#define TXA   0b11010000
//Now some constants for my own use
#define LD_SRC_MEM    0b00000000
#define LD_SRC_IMM    0b00000001
#define LD_SRC_STREAM 0b00000010
#define ST_DST_MEM    0b00000000
#define ST_DST_STREAM 0b00010000
#define ALU_SRC_X     0b00010000 /*also used for jmp*/
#define ALU_SRC_IMM   0b00000000
#define SET_JMP_OFF   0b11100000
#define SET_IMM       0b11110000
#define INVALID_MNEMONIC 0b11111111

#define mkentry(X) {X, #X}

struct {
    unsigned char raw_code;
    char const *str;
} const mnemonics[] = {
    mkentry(LD), mkentry(LDX),
    mkentry(ST), mkentry(STX),
    mkentry(IN), mkentry(INX),
    mkentry(OUT), mkentry(OUTX),
    mkentry(ADD), mkentry(SUB), 
    mkentry(AND), mkentry(OR), mkentry(XOR),
    mkentry(NOT),
    mkentry(MUL), mkentry(DIV), mkentry(MOD),
    mkentry(JA),
    mkentry(JEQ), mkentry(JGT), mkentry(JGE), mkentry(JSET), mkentry(JLAST),
    mkentry(TAX), mkentry(TXA)
};

unsigned char opcode_from_mnemonic(char const *str) {
    static int const len = sizeof(mnemonics)/sizeof(*mnemonics);
    int i;
    for (i = 0; i < len; i++) {
        if (strcmp(str, mnemonics[i].str) == 0) return mnemonics[i].raw_code;
    }
    
    return INVALID_MNEMONIC;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        puts("Usage: assmembler my_source.asm > prog.bit");
        return -1;
    }
    
    if (argv[1][0] == '-') {
        //Always print help
        puts(
        "Usage: assembler my_source.asm > prog.bit\n"
        "\n"
        "prog.bit has a special binary format which represents the sequence\n"
        "of words that must be written to the AXI CPU's cmd_in stream in\n"
        "order to program it\n"
        "\n"
        "Basic syntax (more explanations at end):\n"
        "All instructions can be preceded with a star ('*'). When writing\n"
        "jump instructions, you can use \"+\" to mean \"jump to the next\n"
        "starred instruction\", \"++\" to mean \"jump forward by two starred\n"
        "instructions\", etc. Likewise, use \"-\" to mean \"jump to the\n"
        "last starred instruction (not including this one)\n"
        "You can also use labels with \"@mylabel:\"\n"
        "\n"
        "Opcodes:\n"
        "\tLD (#|Rn)  ==> Load an immediate or Rn into register A\n"
        "\tLDX (#|Rn) ==> Load an immediate or Rn into register X\n"
        "\tST Rn      ==> Save register A into Rn\n"
        "\tSTX Rn     ==> Save register X into Rn\n"
        "\tTAX        ==> Transfer A into X\n"
        "\tTXA        ==> Transfer X into A\n"
        "\tIN         ==> Read from the din stream into A\n"
        "\tINX        ==> Read from the din stream into X\n"
        "\tOUT        ==> Write A to the dout stream\n"
        "\tOUTX       ==> Write X to the dout stream\n"
        "\t(ADD|SUB|MUL|DIV|MOD|LSH|RSH|AND|OR|XOR|NOT) (X|#)\n"
        "             ==> Perform A = (X|#) op A\n"
        "\tJA (+|-)^n ==> Unconditional jump\n"
        "\tJ(EQ|GT|GE|SET) (X|#) (+|-)^n\n"
        "\t           ==> Jump if A...\n"
        "\t               EQ: is equal to\n"
        "\t               GT: is greater than\n"
        "\t               GE: greater than or equal\n"
        "\t               SET: has any 1s in the same position as\n"
        "\t               ...either X or an immediate\n"
        "\tJLAST (+|-)^n ==> Jump if the last flit read had TLAST=1\n"
        "\n"
        "[str] means \"str\" is optional\n"
        "Rn is one of the general purpose registers. Replace n with 0-15\n"
        "# is an immediate. This is parsed using strtol (see man page for details)\n"
        "(A|B) means \"A\" or \"B\"\n"
        "(+|-)^n means n repetitions of either '+' or '-', used for jump dests\n"
        "\n"
        "Extra notes:\n"
        "Accessing an immediate always takes two cycles, but accessing Rn\n"
        "only takes one. Also, because immediates and jump offsets are\n"
        "essentially written into fixed-size ROMs, you can only have a max\n"
        "of 16 of each in any one program. I'm sure you can imagine tricky\n"
        "ways to work around this by adding useless instructions here and\n"
        "there...\n"
        );
    }
    
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) {
        char line[80];
        sprintf(line, "Could not open file [%s]", argv[1]);
        perror(line);
        return -1;
    }
    
    fseek(fp, 0, SEEK_END);
    int len = ftell(fp);
    rewind(fp);
    
    //Read entire file. 
    char *data = malloc(len+1);
    fread(data, len, 1, fp);
    data[len] = 0; //Nul-terminate the string.
    
    //Jump offsets tabnle
    int jmp_table[16];
    int num_jmps = 0;
    
    //Immediates table
    int imm_table[16];
    int num_imms = 0;
    
    //Instructions, stars, and labels
    #define MAX_OPCODES 2048
    #define MAX_STARS 128
    #define MAX_LABELS 64
    unsigned char opcodes[MAX_OPCODES]; //I don't care about making this dynamically sized
    int num_opcodes = 0;
    int starred_opcodes[MAX_STARS]; //Keeps track of addresses of opcodes with a star
    int num_starred = 0;
    char *labels[MAX_LABELS];
    int labels_pos[MAX_LABELS];
    int num_labels;
    
    //Now get to work parsing!
    int curr_addr = 0;
    
    
    
    
    
    
    fclose(fp);
    return 0;
}
