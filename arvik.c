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

    char * archive_name = NULL;
    char ** member_filenames = NULL;
    int num_members = 0;
    // char ** archive_members = (char**) malloc(sizeof(1));
    // char ** filenames = NULL;

    // char c;

    while ((opt = getopt(argc, argv, ARVIK_OPTIONS)) != -1) {
        switch (opt) {
            case 'x':
                extract = 1;
                break;

            case 'c':
                extract = 0;
                break;

            case 't':
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
