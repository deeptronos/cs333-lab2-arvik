#include <ar.h>

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h> 
#include <fcntl.h>
#include <unistd.h>

#include "arvik.h"

#define BUF_SIZE 1024

void usage(void);

void write_to_file(const char * filename, const char * content);
void read_from_file(const char * filename);
void copy_file(const char * from, const char* to);


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
    int opt, extract, deterministic, verbose = 0;

    int toc = 0;
    char * archive_name = NULL;
    char ** member_filenames = NULL;
    int num_members = 0;
    // char ** archive_members = (char**) malloc(sizeof(1));
    // char ** filenames = NULL;

    int iarch = -1;

    while ((opt = getopt(argc, argv, ARVIK_OPTIONS)) != -1) {
        switch (opt) {
            case 'x':
                extract = 1;
                break;

            case 'c':
                extract = 0;
                break;

            case 't':
                toc = 1;
                break;
                
            default:
            case 'h':
                usage();
                break;

            case 'v':
                verbose = 1;
                break;

            case 'D':
                deterministic = 1;
                break;

            case 'U':
                deterministic = 0;
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
        iarch = open(archive_name, O_RDONLY);
    }else{
        exit(NO_ARCHIVE_NAME);
    }


    // TOC
    if(toc == 1){
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
            // memset(buf, 0, 100);
            strncpy(buf, md.ar_name, 16);
            buf[16]='\0';

            // remove trailing '/' if present
            char * slash = strchr(buf, '/');
            if (slash) *slash = '\0';

            printf("%s\n", buf);

            // move file pointer forward
            int file_size = atoi(md.ar_size);
            int padding = (file_size % 2) ? 1 : 0; // Archive aligns file to even numbers via padding 
            lseek(iarch, file_size + padding, SEEK_CUR);

            // if ((back_pos = strchr(buf, '/'))){
            //     *back_pos = '\0';
            // }
            // printf("%s\n", buf);

            // lseek(iarch, atoi(md.ar_size), SEEK_CUR);
        }
        if(archive_name != NULL){
            close(iarch);
        }
        // char * back_pos = NULL;
        // process metadata
        // while ( read(iarch, &md, sizeof(struct ar_hdr)) > 0 ){ // Slides has ar_hdr_t as arvik_header_t... is mine OK?
        //     // print archive member name
        //     memset(buf, 0, 100);
        //     strncpy(buf, md.ar_name, 16);
        //     if ((back_pos = strchr(buf, '/'))){
        //         *back_pos = '\0';
        //     }
        //     printf("%s\n", buf);

        //     lseek(iarch, atoi(md.ar_size), SEEK_CUR);
        // }
        // we finished processing the archive members to the archive file!
        //      read() call returned 0, indicating that we hit end-of-file.
        // if(archive_name != NULL){
        //     close(iarch);
        // }
    }


    fprintf(stderr, "CTEST - archive_name: %s\n", archive_name);
    if (optind < argc){
        num_members = argc - optind;
        member_filenames = malloc(num_members * sizeof(char*));
        if(member_filenames == NULL){
            fprintf(stderr, "Memory allocation failed\n");
            exit(EXIT_FAILURE);
        }

        for(int i =0; i < num_members; ++i){
            member_filenames[i] = argv[optind + i];
        }
    }
    //print members
    fprintf(stderr, "Member_filenames: \n");
    for(int i =0; i < num_members; ++i){
        fprintf(stderr, "%s\n", member_filenames[i]);
    }
    free(member_filenames);

    return 0;
}
