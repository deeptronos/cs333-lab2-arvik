// R Jesse Chaney
// rchaney@pdx.edu

#ifndef _ARVIK_H
# define _ARVIK_H

# include <ar.h>

typedef struct ar_hdr ar_hdr_t;

# define ARVIK_OPTIONS "cxtvDUf:h"

typedef enum {
    ACTION_NONE = 0
    , ACTION_CREATE
    , ACTION_EXTRACT
    , ACTION_TOC
} var_action_t;

// exit values
# define INVALID_CMD_OPTION 2
# define NO_ARCHIVE_NAME    3
# define NO_ACTION_GIVEN    4
# define EXTRACT_FAIL       5
# define CREATE_FAIL        6
# define TOC_FAIL           7
# define BAD_TAG            8

# ifndef MIN
#  define MIN(_A,_B) (((_A) < (_B)) ? (_A) : (_B))
# endif // MIN

#endif // _ARVIK_H
