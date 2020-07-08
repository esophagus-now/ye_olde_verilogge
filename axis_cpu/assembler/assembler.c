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

typedef struct _lex_state {
    char *str;
    char *line;
    int current_line;
    int eof;
    char *err_str;

    char *word_saveptr;
} lex_state;

lex_state *new_lex_state(char *str) {
    lex_state *ret = malloc(sizeof(lex_state));
    
    ret->str = str;
    //Initialize line to point to the first line
    ret->line = strsep(&ret->str, "\n");
    //and strip off comments
    ret->line = strsep(&ret->line, ";");
    
    ret->current_line = 1;
    ret->eof = (ret->str == NULL); //Boundary case: empty string passed
    ret->err_str = NULL;
    
    //saveptr for strtok_r
    ret->word_saveptr = NULL;

    return ret;
}

void del_lex_state(lex_state *l) {
    if (l == NULL) return;
    
    if (l->err_str) free(l->err_str);
    
    free(l);
}

//Returns word on success, NULL on EOF or error. 
//Does not care one bit about efficieny! Cares only about robustness
char *get_word(lex_state *l) {        
    //Try reading a word
    char *word;
    try_again:
    word = strtok_r(l->line, " ,:#$%.", &l->word_saveptr);
    l->line = NULL;
    if (!word || word[0] == '\n' || word[0] == '\0') {
        if (l->eof) return NULL;
        l->line = strsep(&l->str, "\n");
        l->line = strsep(&l->line, ";");
        l->current_line++;
        if (!l->str) {
            l->eof = 1;
        }
        goto try_again;
    }
    
    return word;
}

//Opcodes for each string the user can type
//Some of these are incomplete because they have fields that are filled in
//when the rest of the instruction is parsed
#define LD    0b00000000 /*LD/LDX use lower 3 bits to select source*/
#define LDX   0b00100000
#define ST    0b01000000
#define STX   0b01100000
#define IN    0b00001000
#define INX   0b00101000
#define OUT   0b01010000
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
#define JEQ   0b10100001
#define JGT   0b10100010
#define JGE   0b10100011
#define JSET  0b10100100
#define JLAST 0b10100101
#define TAX   0b11000000
#define TXA   0b11010000
#define IMM   0b11110000
//Now some constants for my own use
#define LD_SRC_MEM    0b00010000
#define LD_SRC_IMM    0b00000000
#define LD_SRC_STREAM 0b00001000
#define ST_DST_MEM    0b00000000
#define ST_DST_STREAM 0b00010000
#define ALU_SRC_X     0b00010000 /*also used for jmp*/
#define ALU_SRC_IMM   0b00000000
#define SET_JMP_OFF   0b11100000
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
    mkentry(TAX), mkentry(TXA),
    mkentry(IMM)
};

//Does not care about efficiency
unsigned char opcode_from_mnemonic(char const *str) {
    static int const len = sizeof(mnemonics)/sizeof(*mnemonics);
    int i;
    for (i = 0; i < len; i++) {
        if (strcasecmp(str, mnemonics[i].str) == 0) return mnemonics[i].raw_code;
    }
    
    return INVALID_MNEMONIC;
}

int main(int argc, char **argv) {
    int ret = 0;
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
        "Comments begin with a \";\" and continue until the end of the line.\n"
        "All instructions can be preceded with a star ('*'). When writing\n"
        "jump instructions, you can use \"+\" to mean \"jump to the next\n"
        "starred instruction\", \"++\" to mean \"jump forward by two starred\n"
        "instructions\", etc. Likewise, use n \"-\" characters, to mean \"jump \n"
        "backwards by n starred instructions (not including this one)\n"
        "You can also use labels with \"@mylabel:\"\n"
        "\n"
        "Labels:\n"
        "\t*             ==> Anonymous label (explained in above paragraph)\n"
        "\t@label        ==> Replace \"label\" with a unique string (keep the @)\n"
        "Opcodes:\n"
        "\tIMM #         ==> Set the immediate value to #.\n"
        "\tLD (IMM|Rn)   ==> Load the immediate or Rn into register A\n"
        "\tLDX (IMM|Rn)  ==> Load the immediate or Rn into register X\n"
        "\tST Rn         ==> Save register A into Rn\n"
        "\tSTX Rn        ==> Save register X into Rn\n"
        "\tTAX           ==> Transfer A into X\n"
        "\tTXA           ==> Transfer X into A\n"
        "\tIN            ==> Read from the din stream into A\n"
        "\tINX           ==> Read from the din stream into X\n"
        "\tOUT           ==> Write A to the dout stream\n"
        "\tOUTX          ==> Write X to the dout stream\n"
        "\t(ADD|SUB|MUL|DIV|MOD|LSH|RSH|AND|OR|XOR|NOT) (X|IMM)\n"
        "                ==> Perform A = (X|IMM) op A\n"
        "\tJA <loc>      ==> Unconditional jump\n"
        "\tJ(EQ|GT|GE|SET) (IMM|X) <loc>\n"
        "\t              ==> Jump to <loc> if A...\n"
        "\t                      EQ: is equal to\n"
        "\t                      GT: is greater than\n"
        "\t                      GE: greater than or equal\n"
        "\t                      SET: has any 1s in the same position as\n"
        "\t                  ...either X or the immediate\n"
        "\tJLAST <loc>   ==> Jump to <loc> if the last flit read had TLAST=1\n"
        "\n"
        "X or IMM as a parameter means to literally type the string \"X\" or \"IMM\"\n"
        "Rn       is one of the general purpose registers. Replace n with 0-15\n"
        "#        is a 32-bit integer. Parsed using strtol (see `man strtol` for details)\n"
        "(A|B)    means \"A\" or \"B\"\n"
        "<loc>    is a code location. It could n repetitions of either '+' or '-' to\n"
        "         select a starred instruction (see first paragraph of this help) or\n"
        "         \"@label\" to select a label\n"
        "\n"
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
    struct {
        unsigned char code;
        char *jmp_label;
        int jmp_stars;
    } opcodes[MAX_OPCODES]; //I don't care about making this dynamically sized
    int num_opcodes = 0;
    
    int starred_opcodes[MAX_STARS]; //Keeps track of addresses of opcodes with a star
    int num_starred = 0;
    
    char *labels[MAX_LABELS];
    int labels_pos[MAX_LABELS]; //Label positions
    int num_labels;
    
    //Now get to work parsing!
    int curr_addr = 0;
    
    lex_state *l = new_lex_state(data);
    
    //Pass 1: convert mnemonics to opcodes and get addresses for labels and
    //stars
    while(1) {
        char *word = get_word(l);
        if (word == NULL) break;
        
        if (word[0] == '*') {
            //Add to list of starred instructions
            starred_opcodes[num_starred++] = curr_addr;
            if (word[1] == '\0') {
                word = get_word(l);
                if (word == NULL) {
                    fprintf(stderr, "Error, line %d: Expected instruction after '*'\n", l->current_line);
                    ret = -1;
                    goto cleanup;
                }
            } else {
                word++; //Read past star
            }
        } else if (word[0] == '@') {
            //Check if label is already there
            int i;
            for (i = 0; i < num_labels; i++) {
                if (strcmp(labels[i], word) == 0) {
                    fprintf(stderr, "Error, line %d: duplicate label\n", l->current_line);
                    ret = -1;
                    goto cleanup;
                }
            }
            //Add to list of labels
            labels[num_labels] = word;
            labels_pos[num_labels] = curr_addr;
            num_labels++;
            word = get_word(l);
            if (word == NULL) {
                fprintf(stderr, "Error, line %d: Expected instruction after label\n", l->current_line);
                ret = -1;
                goto cleanup;
            }
        }
        
        //At this point, word should contain a mnemonic
        unsigned char code = opcode_from_mnemonic(word);
        if (code == INVALID_MNEMONIC) {
            fprintf(stderr, "Error, line %d: Invalid mnemonic [%s]\n", word);
            ret = -1;
            goto cleanup;
        }
        
        switch(code) {
        case LD:
        case LDX:
            //Need to read a single parameter, the string "X" or the string
            //"IMM". Then need to modify the raw opcode to set the addr_type
            //field in bits 4:3
            break;
        case ST:
        case STX:
            //Need to read a single parameter, a string "Rn" where n is an 
            //integer from 0-15
            break;
        case ADD:
        case SUB:
        case MUL:
        case DIV:
        case MOD:
        case LSH:
        case RSH:
        case AND:
        case OR:
        case XOR:
        case NOT:
            //Need to read a single parameter, the string "X" or the string
            //"IMM".
            break;
            
        }
        
    }
    
    
    
    cleanup:
    del_lex_state(l);
    free(data);
    fclose(fp);
    return ret;
}
