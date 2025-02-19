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

// bad fxns: TODO
void write_to_file(const char * filename, const char * content);
void read_from_file(const char * filename);
void copy_file(const char * from, const char* to);

void trim_leading_whitespace(char *s){ // Credit to https://www.delftstack.com/howto/c/trim-string-in-c/
    int start = 0, end = strlen(s) - 1;
    while(isspace(s[start])) {
        start++;
    }
    while (end > start && isspace(s[end])) {
        end--;
    }

    // If the string was trimmed, adjust the null terminator
    if (start > 0 || end < (strlen(s) - 1)) {
        memmove(s, s + start, end - start + 1);
        s[end - start + 1] = '\0';
    }

}

void usage(void) {
    fprintf(stderr, "Usage: arvik -[cxtvDUf:h] archive-file file...\n");
    fprintf(stderr, "\t-x\tExtract members from arvik file.\n");
    fprintf(stderr, "\t-c\tCreate an arvik style archive.\n");
    fprintf(stderr, "\t-t\tTable of contents.\n");
    fprintf(stderr, "\t-f filename\tSpecify the name of the arvik file on which to operate.\n");
    fprintf(stderr, "\t-h\tShow the help text and exit.\n");
    fprintf(stderr, "\t-v\t Verbose processing.\n");
    fprintf(stderr, "\t-D\tOperate in deterministic mode.\n");
    fprintf(stderr, "\t-U\tDo not operate in deterministic mode. This is the DEFAULT mode for arvik. It is not the default mode for ar.\n");
    exit(1);
}


void write_to_file(const char * filename, const char * content) {
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
    if(fd == -1) {
        fprintf(stderr, "Error opening file %s for writing\n", filename);
        exit(EXIT_FAILURE);
    }
    if (write(fd, content, strlen(content)) == -1){
        fprintf(stderr, "Error writing contents to file %s\n", filename);
        exit(EXIT_FAILURE);
    }
    close(fd);
}

void read_from_file(const char * filename) {
    int fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
    if(fd == -1) {
        fprintf(stderr, "Error opening file %s for reading\n", filename);
        return;
    }
    char buffer[BUF_SIZE];
    ssize_t bytes_read;
    while((bytes_read = read(fd, buffer, BUF_SIZE)) > 0){
        write(STDOUT_FILENO, buffer, bytes_read); // print to stdout
    }
    close(fd);
}

void copy_file(const char * from, const char * to){
    int src_fd = open(from, O_RDONLY);
    if(src_fd == -1){
        fprintf(stderr, "Error opening source file %s", from);
        return;
    }
    int dest_fd = open(to, O_WRONLY | O_CREAT | O_TRUNC, 0664);
    if(dest_fd == -1){
        fprintf(stderr, "Error opening destination file %s", to);
    }

    char buffer[BUF_SIZE];
    ssize_t bytes_read;
    while ((bytes_read = read(src_fd, buffer, BUF_SIZE)) > 0){
        if (write(dest_fd, buffer, bytes_read) != bytes_read) {
            fprintf(stderr, "Error writing to destination");
        }
    }
    close (src_fd);
    close(dest_fd);
}

int main(int argc, char **argv){
    int opt = 0;
    int extract_flag, deterministic_flag, verbose_flag = -1;

    int toc_flag = 0;
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
                deterministic_flag = 1;
                break;

            case 'U':
                deterministic_flag = 0;
                break;

            case 'f':
                if(!optarg  || strlen(optarg) < 1){
                    fprintf(stderr, "Option -f requires a non-empty argument.\n"); // TODO sufficient error handling?
                    usage();
                }
                // Copy archive name passed as argument to archive_name char array...
                archive_name = malloc(sizeof(char) * strlen(optarg)); // TODO if memory is weird, the size calculations here should be checked. // TODO free this shit!
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
        iarch = open(archive_name, O_RDONLY);
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
        char buf[17] = {'\0'};
        // validate tag
        read(iarch, buf, SARMAG);

        if(strncmp(buf, ARMAG, SARMAG) != 0){
            // not a valid arkiv file
            // print message and exit(1);
            fprintf(stderr, "Invalid archive file X_X");
            exit(EXIT_FAILURE);
        }

        struct ar_hdr md;
        // process metadata
        while ( read(iarch, &md, sizeof(struct ar_hdr)) > 0 ){ // Slides has ar_hdr_t as arvik_header_t... is mine OK?
            // print archive member name
            strncpy(buf, md.ar_name, 16);
            buf[16]='\0';

            // remove trailing '/' if present
            char * slash = strchr(buf, '/');
            if (slash) *slash = '\0';

            if (verbose_flag){ // -v passed...
                // Convert mode to symbolic permissions (logic here provided to me via a conversation with ChatGPT)
                int mode = strtol(md.ar_mode, NULL, 8);
                char perm[11] = {'-', '-', '-', '-', '-', '-', '-', '-', '-', '-', '\0'};
                char perms[] = "rwxrwxrwx";
                for ( int i = 0; i < 9; ++i){
                    if (mode & (1 << (8 - i))) perm[i+1] = perms[i];
                }

                // extract UID and GUID
                int uid = atoi(md.ar_uid);
                int gid = atoi(md.ar_gid);
                
                int file_size = atoi(md.ar_size);

                // extract timestamp
                // convert timestamp
                time_t mod_time = atol(md.ar_date);
                struct tm *tm_info = localtime(&mod_time);
                char time_buf[32];
                strftime(time_buf, sizeof(time_buf), "%b %e %H:%M %Y", tm_info);

                 // print verbose output
                printf("%s %d/%d %7d %s %s\n", perm, uid, gid, file_size, time_buf, buf);
            }
            else{
                printf("%s\n", buf);
            }

            // carefully move file pointer forward to next header, considering padding
            int file_size = atoi(md.ar_size);
            int padding = (file_size % 2) ? 1 : 0; // archive aligns file to even numbers via padding 
            lseek(iarch, file_size + padding, SEEK_CUR);
        }
        if(archive_name != NULL){
            close(iarch);
        }
      
    }

    // Extraction
    if(extract_flag){

        char buf[17] = {'\0'};
        // valiate ARMAG header
        read(iarch, buf, SARMAG);
        if(strncmp(buf, ARMAG, SARMAG) != 0){
            // not a valid arkiv file
            // print message and exit(1);
            fprintf(stderr, "Invalid archive file X_X");
            exit(EXIT_FAILURE);
        }

        struct ar_hdr hdr;
        // process metadata
        while ( read(iarch, &hdr, sizeof(struct ar_hdr)) > 0 ){
            // Copy name from file header to buf
            strncpy(buf, hdr.ar_name, 16);
            buf[16]='\0'; // Now null-terminate it
            // remove trailing '/' if present in name
            char * slash = strchr(buf, '/');
            if (slash) *slash = '\0';

            int file_size = atoi(hdr.ar_size);
            // Open out file with permissions derived from header
            int derived_mode = strtol(hdr.ar_mode, NULL, 8);

            int out_fd = open(buf, O_WRONLY | O_CREAT | O_TRUNC, derived_mode);
            if(out_fd < 0){
                fprintf(stderr, "Failed to open file for writing out '%s'\n", buf);
                exit(EXIT_FAILURE);
            }

            // Write content to out_fd
            ssize_t bytes_read;
            while((bytes_read = read(iarch, buf, BUF_SIZE)) > 0){ // Read (from file at iarch) and write that to out_fd.
                write(out_fd, buf, bytes_read);
            }

            
            int uid = atoi(hdr.ar_uid);
            int gid = atoi(hdr.ar_gid);
            // Extract original time
            time_t mod_time = atol(hdr.ar_date);
            struct tm *tm_info = localtime(&mod_time);
            struct utimbuf times;
            times.actime = time(0);  // Last-accessed time (right now!)
            times.modtime = mod_time; // last-modified time (from archive)

            // Store original filename in filename
            char filename [17] = {'\0'};
            strncpy(filename, hdr.ar_name, 16);
            buf[16]='\0'; // Now null-terminate it
            utime(filename, &times);
            // Set file permissions
            mode_t mode = (mode_t)strtol(hdr.ar_mode, NULL, 8);
            fchmod(out_fd, mode);

            if(verbose_flag){ printf("x %s\n", buf);}
            lseek(iarch, file_size + (file_size % 2), SEEK_CUR);
        }
        if(verbose_flag){ printf("\t Completed extraction.");}
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

    return 0;
}
 