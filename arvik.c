#include <ar.h>

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h> 
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <utime.h>
#include <sys/stat.h>

#include "arvik.h"

#define BUF_SIZE 1024

void usage(void);
void  trim_leading_whitespace(char *s);

void trim_leading_whitespace(char *s){ // Credit to https://www.delftstack.com/howto/c/trim-string-in-c/
    int start = 0, end = strlen(s) - 1;
    while(isspace(s[start])) {
        start++;
    }
    while (end > start && isspace(s[end])) {
        end--;
    }

    // If the string was trimmed, adjust the null terminator
    if (start > 0 || (size_t) end < (strlen(s) - 1)) {
        memmove(s, s + start, end - start + 1);
        s[end - start + 1] = '\0';
    }

}

void usage(void) {
    fprintf(stderr, "Usage: arvik -[cxtvDUf:h] archive-file file...\n");
    fprintf(stderr, "\t-c\t\tcreate a new archive file.\n");
    fprintf(stderr, "\t-x\t\textract members from an existing archive file.\n");
    fprintf(stderr, "\t-t\t\tshow the table of contents of archive file\n");
    
    fprintf(stderr, "\t-D\t\tDeterminisatic mode: all timestamps are 0, all owership is 0, permmissions are 0644.\n");
    fprintf(stderr, "\t-U\t\tNon-determinisatic mode: all timestamps are correct, all owership is saved, permmissions are as on source files.\n");
    fprintf(stderr, "\t-f filename\tname of archive file to use\n");
    fprintf(stderr, "\t-v\t\tVerbose output\n");
    fprintf(stderr, "\t-h\t\tshow help text\n");
    
    
    exit(1);
}

int main(int argc, char **argv){
    int opt = 0;
    int extract_flag,  verbose_flag = -1;

    int toc_flag = -1;
    char * archive_name = NULL;
    char ** member_filenames = NULL;
    int num_members = 0;
    // char ** archive_members = (char**) malloc(sizeof(1));
    // char ** filenames = NULL;

    int iarch = -1;

    while ((opt = getopt(argc, argv, ARVIK_OPTIONS)) != -1) {
        switch (opt) {
            case 'x':
                extract_flag = 1;
                break;

            case 'c':
                extract_flag= 0;
                break;

            case 't':
                toc_flag = 1;
                break;
                
            default:
            case 'h':
                usage();
                break;

            case 'v':
                verbose_flag = 1;
                break;

            case 'D':
                // deterministic_flag = 1;
                break;

            case 'U':
                // deterministic_flag = 0;
                break;

            case 'f':
                if(!optarg  || strlen(optarg) < 1){
                    fprintf(stderr, "Option -f requires a non-empty argument.\n"); // TODO sufficient error handling?
                    usage();
                }
                // Copy archive name passed as argument to archive_name char array...
                archive_name = malloc(sizeof(char) * strlen(optarg)); // TODO if memory is weird, the size calculations here should be checked. 
                strncpy(archive_name, optarg, strlen(optarg));
                archive_name[strlen(optarg)] = '\0'; // TODO ok?
                break;
            // default:
            //     usage();
            //     break;
        }
    }
    // If user supplied -f, open() that thang
    if(archive_name != NULL){
        trim_leading_whitespace(archive_name);
        iarch = open(archive_name, O_RDONLY | O_CREAT);
        // Make sure open worked correctly...
        if(iarch == -1){
            fprintf(stderr, "Error opening source file %s", archive_name);
            exit(EXIT_FAILURE);
        }
    }else{
        exit(NO_ARCHIVE_NAME);
    }


    // TOC
    if(toc_flag == 1){
        struct ar_hdr md;
        char buf[17] = {'\0'};
        // validate tag
        read(iarch, buf, SARMAG);

        if(strncmp(buf, ARMAG, SARMAG) != 0){
            // not a valid arkiv file
            // print message and exit(1);
            fprintf(stderr, "Invalid archive file X_X\n");
            exit(EXIT_FAILURE);
        }

        
        // process metadata
        while ( read(iarch, &md, sizeof(struct ar_hdr)) > 0 ){ // Slides has ar_hdr_t as arvik_header_t... is mine OK?
            
            // Moved from if(verbose_flag) because it was triggering warnings
            // extract UID and GUID 
            int uid = atoi(md.ar_uid);
            int gid = atoi(md.ar_gid);
            int file_size = atoi(md.ar_size);
            // extract timestamp
            time_t mod_time = atol(md.ar_date);

            char slash;
            int padding;
            // convert timestamp
            struct tm *tm_info = localtime(&mod_time);
            char time_buf[32];

            // print archive member name
            strncpy(buf, md.ar_name, 16);
            buf[16]='\0';

            // remove trailing '/' if present
           slash = *strchr(buf, '/');
            if (slash) slash = '\0';

            if (verbose_flag){ // -v passed...
                // Convert mode to symbolic permissions (logic here provided to me via a conversation with ChatGPT)
                int mode = strtol(md.ar_mode, NULL, 8);
                char perm[11] = {'-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '\0'};
                char perms[] = "rwxrwxrwx";
                for ( int i = 0; i < 9; ++i){
                    if (mode & (1 << (8 - i))) perm[i+1] = perms[i];
                }

                strftime(time_buf, sizeof(time_buf), "%b %e %H:%M %Y", tm_info);

                 // print verbose output
                printf("%s %d/%d %7d %s %s\n", perm, uid, gid, file_size, time_buf, buf);
            }
            else{
                printf("%s\n", buf);
            }

            // carefully move file pointer forward to next header, considering padding
            file_size = atoi(md.ar_size);
            padding = (file_size % 2) ? 1 : 0; // archive aligns file to even numbers via padding 
            lseek(iarch, file_size + padding, SEEK_CUR);
        }
        if(archive_name != NULL){
            close(iarch);
        }
      
    }

    // Extraction
    if(extract_flag == 1){
        struct ar_hdr hdr;
        char buf[17] = {'\0'};
        // valiate ARMAG header
        read(iarch, buf, SARMAG);
        if(strncmp(buf, ARMAG, SARMAG) != 0){
            // not a valid arkiv file
            // print message and exit(1);
            fprintf(stderr, "Invalid archive file X_X\n");
            exit(EXIT_FAILURE);
        }

        
        // process metadata
        while ( read(iarch, &hdr, sizeof(struct ar_hdr)) > 0 ){
            char * slash;
            char fname[17];
            char content[BUF_SIZE];
            int out_fd;
            int file_size = atoi(hdr.ar_size);
            int derived_mode = strtol(hdr.ar_mode, NULL, 8);
            int remaining;
            struct utimbuf times;

            // Copy and clean up the file name from the header
            strncpy(fname, hdr.ar_name, 16);
            fname[16] = '\0';
            
            slash = strchr(fname, '/');
            // char *slash = strchr(fname, '/');
            // if (slash){*slash = '\0';}
            if (slash){*slash = '\0';}

            
            
            // Open the output file using the cleaned-up name
            out_fd = open(fname, O_WRONLY | O_CREAT | O_TRUNC, derived_mode);
            if (out_fd < 0) {
                fprintf(stderr, "Failed to open file %s for writing\n", fname);
                exit(EXIT_FAILURE);
            }

            // Read exactly file_size bytes from the archive and write to out_fd
            remaining = file_size;
            while (remaining > 0) {
                int to_read = (remaining < BUF_SIZE) ? remaining : BUF_SIZE;
                int n = read(iarch, content, to_read);
                if (n <= 0) {
                    perror("read failed");
                    break;
                }
                write(out_fd, content, n);
                remaining -= n;
            }

            // Skip the padding byte if file_size is odd
            if (file_size % 2 != 0)
                lseek(iarch, 1, SEEK_CUR);

            // Set the file's modification time and permissions
            
            times.actime = time(NULL);
            times.modtime = atol(hdr.ar_date);
            utime(fname, &times);
            fchmod(out_fd, derived_mode);

            if (verbose_flag)
                printf("x %s\n", fname);

            close(out_fd);
    }
    }
    // Process optional filenames at end of invocation
    if (optind < argc){
        num_members = argc - optind;
        if(num_members < 1){
            return 0; // TODO graceful?
        }
        member_filenames = malloc(num_members * sizeof(char*));
        if(member_filenames == NULL){
            fprintf(stderr, "Memory allocation failed\n");
            exit(EXIT_FAILURE);
        }

        for(int i = 0;  i< num_members; ++i){
            member_filenames[i] = strdup(argv[optind + i]);
            if(member_filenames[i] == NULL){
                fprintf(stderr, "Memory allocation failed for filename\n");
                exit(EXIT_FAILURE);
            }
        }
  
        for(int i =0; i < num_members; ++i){
            printf("\tfilename:%s\n", member_filenames[i]);
        }
    }

    // Clean up memory allocated for optional filenames
    for (int i = 0; i < num_members; ++i){
        free(member_filenames[i]);
    }
    free(member_filenames);

    free(archive_name);
    return 0;
}

 