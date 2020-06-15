//I just wanted to make a quick and dirty program to read raw bytes from the
//debug guvs and print out the parsed information. Then, I figured if I was
//going to the trouble of doing it, I would at least put it in with the 
//debug guv.

//This program just reads from STDIN, which is good enough for me. I will
//probably be able to copy and paste certain parts of this code when I go on
//to edit my UI

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void print_TID(int size, unsigned TID) {
    printf("\tTID (%02db)   =%u\n", size, TID);
}
void print_TDEST(int size, unsigned TDEST) {
    printf("\tTDEST (%02db) =%u\n", size, TDEST);
}
void print_receipt(unsigned rx) {
    printf("Command receipt:\n");
    printf("\tADDR          = %u\n", (rx & 0x1FFF));
    printf("\tkeep_pausing  = %u\n", ((rx>>14) & 1));
    printf("\tkeep_logging  = %u\n", ((rx>>15) & 1));
    printf("\tkeep_dropping = %u\n", ((rx>>16) & 1));
    printf("\t| log_cnt     = %u\n", ((rx>>17) & 1));
    printf("\t| drop_cnt    = %u\n", ((rx>>18) & 1));
    printf("\tinj_TVALID    = %u\n", ((rx>>19) & 1));
    printf("\tdut_reset     = %u\n", ((rx>>20) & 1));
    printf("\tinj_failed    = %u\n", ((rx>>21) & 1));
    printf("\tdout_not_rdy  = %u\n", (rx>>22));
}

//Returns 0 on end-of-stream or <0 on error
int read_word(unsigned *u) {
    int num_read = 0;
    //Read in a loop until word is filled, or end-of-stream
    char *pos = (char*) u;
    int rc;
    while (num_read < 4) {
        rc = read(STDIN_FILENO, pos + num_read, 4 - num_read);
        if (rc <= 0) break;
        num_read += rc;
    }
    
    return rc;
}

int main() {
    
    while (1) {
        fflush(stdout);
        unsigned word;
        int rc = read_word(&word);
        
        //End-of-stream or error
        if (rc <= 0) {
            printf("End of stream?\n");
            break;
        }
        
        //Check if command or log
        if ((word>>13) & 1) {
            print_receipt(word);
            continue;
        }
        
        //This is a log. 
        printf("Log:\n");
        printf("\tADDR       = %u\n", (word & 0x1FFF));
        printf("\tTLAST      = %u\n", ((word>>19) & 1));
        
        //Figure out sizes of AXI Stream channels
        int TID_width = ((word>>20) & 0x3F);
        int TDEST_width = ((word>>26) & 0x3F);
        int log_len = ((word>>14) & 0x1F) + 1; //Size of TDATA in bytes
        
        //Print out TID and TDEST, if present
        int sum = TID_width + TDEST_width;
        if (0 < sum && sum <= 32) {
            //TDEST and TID are in a single word
            rc = read_word(&word);
            if (rc <= 0) {
                fprintf(stderr, "Stream ended prematurely\n");
                exit(1);
            }
            
            print_TID(TID_width, (word>>TDEST_width));
            print_TDEST(TDEST_width, (word & ((1 << TDEST_width) - 1)));
        } else if (sum > 32) {
            //TDEST and TID are in separate words
            rc = read_word(&word);
            if (rc <= 0) {
                fprintf(stderr, "Stream ended prematurely\n");
                exit(1);
            }
            
            print_TID(TID_width, word);
            
            rc = read_word(&word);
            if (rc <= 0) {
                fprintf(stderr, "Stream ended prematurely\n");
                exit(1);
            }
            
            print_TDEST(TDEST_width, word);
        }
        
        //Print TDATA
        if (log_len == 0) {
            printf("\tNo TDATA???\n");
            continue;
        } else {
            printf("\tTDATA (%02dB) = ", log_len);
        }
        
        //Read all complete words
        while (log_len >= 4) {
            rc = read_word(&word);
            if (rc <= 0) {
                fprintf(stderr, "Stream ended prematurely\n");
                exit(1);
            }
            
            log_len -= 4;
            
            printf("%08x", word);
        }
        
        //Read partial words (if necessary)
        if (log_len > 0) {
            rc = read_word(&word);
            if (rc <= 0) {
                fprintf(stderr, "Stream ended prematurely\n");
                exit(1);
            }
            
            //This value is right-padded, so right-shift it to the proper
            //place value:
            word >>= 8*(4 - log_len);
            
            printf("%0*x", log_len*2, word);
        }
        
        //Finish off by printing a newline:
        printf("\n");
    }
}
