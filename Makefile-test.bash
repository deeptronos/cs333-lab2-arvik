#!/bin/bash

# R Jesse Chaney
# 

CLASS=cs333
TERM=w25
LAB=Lab2
PROG=arvik
JDIR=~rchaney/Classes/${CLASS}/Labs/${LAB}
#JDIR=~rchaney/Classes/${CLASS}/Labs/src/${PROG}

VERBOSE=0
TOTAL_POINTS=0
MAKE_POINTS=0
WARN_POINTS=0
SUM_ONLY=0
CLEANUP=1
CLEAN_TARG=""

buildPart()
{
    if [ ${VERBOSE} -eq 1 -a ${SUM_ONLY} -eq 0 ]
    then
	    echo "    Trying \"make $1\""
    fi

    rm -f $1
    make ${CLEAN_TARG} > /dev/null 2>&1
    make $1 > /dev/null 2>&1 
    if [ $? -eq 0 ]
    then
	    ((MAKE_POINTS+=2))
	    echo "      >> Passed \"make $1\"   ${MAKE_POINTS}"
    else
        echo "         Missing the $1 target in Makefile or too many errors during compilation."
    fi
}

build()
{
    BuildFailed=0

    if [ ${VERBOSE} -eq 1 ]
    then
	    echo ""
	    echo "Testing ${FUNCNAME} (the Makefile)"
    fi

    if [ ! -f Makefile -a ! -f makefile ]
    then
	    echo "      >>> There is no makefile or Makefile. This is bad. <<<"
	    echo "      >>>   Nothing can be built, all tests fail.        <<<"
	    echo "      >>>                                                <<<"
	    return
    fi

    #rm -f ${PROG}.h
    ln -fs ${JDIR}/${PROG}.h .
    
    make all > /dev/null
    if [ -e ${PROG} -a -e ${PROG}.o ]
    then
        ((MAKE_POINTS+=7))
    else
        echo "'make all' does not build both ${PROG} and ${PROG}.o you need to fix this to continue"
        exit 1
    fi
    
    make clean > /dev/null
    if [ $? -eq 2 ]
    then
        echo "no target clean"
    
        make cls > /dev/null
        if [ $? -eq 2 ]
        then
            echo "no target cls"
        else
            CLEAN_TARG=cls
            ((MAKE_POINTS+=5))
        fi
    else
        CLEAN_TARG=clean
        ((MAKE_POINTS+=5))
    fi

#    if [ -e ${PROG} -o -e ${PROG}.o ]
#    then
#        echo "'make clean' does not delete both ${PROG} and ${PROG}.o you need to fix this to continue"
#        exit 2
#   fi
#    ((MAKE_POINTS+=5))
    
    if [ $? -eq 0 ]
    then
        ((MAKE_POINTS+=2))
	    if [ ${VERBOSE} -eq 1 -a ${SUM_ONLY} -eq 0 ]
	    then
	        echo "    Passed \"make clean\""
	    fi
    else
	    if [ ${VERBOSE} -eq 1 -a ${SUM_ONLY} -eq 0 ]
	    then
	        echo "    >> Failed \"make clean/cls\""
	        echo "       Missing the clean/cls target in Makefile"
	    fi
    fi

    for TARG in all ${PROG}.o ${PROG}
    do
	    buildPart ${TARG}
    done

    make ${CLEAN_TARG} > /dev/null 2>&1
    if [ -e ${PROG} ]
    then
        echo "make ${CLEAN_TARG} does not remove executables: -1"
        ((MAKE_POINTS-=1))
    fi
    if [ -e ${PROG}.o ]
    then
        echo "make ${CLEAN_TARG} does not remove .o files: -1"
        ((MAKE_POINTS-=1))
    fi

    make ${CLEAN_TARG} > /dev/null 2>&1
    make 2> WARN.err > WARN.out

    NUM_BYTES=`wc -c < WARN.err`
    if [ ${NUM_BYTES} -eq 0 ]
    then
	    ((MAKE_POINTS+=2))
        echo "      You had no warnings messages. Good job."
    else
        echo "      >> You had warnings messages. That is -20 percent!"
        echo "      >> The 20% will also be deducted from the viktar-test.bash tests"
    fi

    for FLAG in -Wall -Wextra -Wshadow -Wunreachable-code -Wredundant-decls \
                      -Wmissing-declarations -Wold-style-definition \
                      -Wmissing-prototypes -Wdeclaration-after-statement \
                      -Wno-return-local-addr -Wunsafe-loop-optimizations \
                      -Wuninitialized -Werror
    do
	    if [ ${VERBOSE} -eq 1 -a ${SUM_ONLY} -eq 0 ]
	    then
	        echo "    Looking for \"${FLAG}\" in build log"
	    fi

	    grep -c -- ${FLAG} WARN.out > /dev/null
	    if [ $? -eq 0 ]
	    then
	        ((MAKE_POINTS+=1))
	        if [ ${VERBOSE} -eq 1 -a ${SUM_ONLY} -eq 0 ]
	        then
		        echo "      Passed use of gcc flag ${FLAG}   ${MAKE_POINTS}"
	        fi
	    else
            echo "    *** Failed gcc flag ${FLAG} ***"
	        if [ ${VERBOSE} -eq 1 -a ${SUM_ONLY} -eq 0 ]
	        then
		        echo "      >> Failed gcc flag ${FLAG}"
		        echo "         Missing from compiler flags; ${FLAG}"
	        fi
	    fi
    done

    echo "** Makefile points: ${MAKE_POINTS} of 35 **"

    ((TOTAL_POINTS+=${MAKE_POINTS}))

    if [ ${CLEANUP} -eq 1 ]
    then
	    rm -f ./WARN*
    fi
}

while getopts "xvC" opt
do
    case $opt in
	v)
	    # Print extra messages.
	    VERBOSE=1
	    ;;
	x)
	    # If you really, really, REALLY want to watch what is going on.
	    echo "Hang on for a wild ride."
	    set -x
	    ;;
	C)
	    # Skip removal of data files
	    CLEANUP=0
	    ;;
	\?)
	    echo "Invalid option" >&2
	    echo ""
	    #showHelp
	    exit 1
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    exit 1
	    ;;
    esac
done

build
make -s ${CLEAN_TARG}
