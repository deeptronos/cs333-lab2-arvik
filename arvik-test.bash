#!/bin/bash

# R Jesse Chaney
# rchaney@pdx.edu

PROG=arvik
AR_PROG=ar

SUM=md5sum
CLASS=cs333
POINTS=5
TOTAL_POINTS=365
POINTS_PER_TEST=15
CLEANUP=1
WARNINGS=0
FILE_HOST=babbage
DIFF=diff
#DIFF_OPTIONS="-B -w -i"
DIFF_OPTIONS="-w"
FAIL_COUNT=0
LAB=Lab2
VERBOSE=0
CORE_COUNT=0
VALGRIND=valgrind
NOLEAKS="All heap blocks were freed -- no leaks are possible"
LEAKS_FOUND=0

TO=10s
TOS="-s QUIT --kill-after=60 --preserve-status"

SDIR=${PWD}
JDIR=~rchaney/Classes/${CLASS}/Labs/${LAB}
#JDIR=~rchaney/Classes/${CLASS}/Labs/src/${PROG}

SPROG=${SDIR}/${PROG}
JPROG=${JDIR}/${PROG}

CORRUPT_FILE=JUNK

signalCaught()
{
    echo "++++ caught signal while running script ++++"
}

signalCtrlC()
{
    echo "Caught Control-C"
    echo "You will neeed to clean up some files"
    exit
}

signalSegFault()
{
    echo "+++++++ Caught Segmentation Fault from your program! OUCH!  ++++++++"
}

coreDumpMessage()
{
    if [ $1 -eq 139 ]
    then
        echo "      >>> core dump during $2 testing"
        ((CORE_COUNT++))
    elif [ $1 -eq 137 ]
    then
        echo "      >>> core dump during $2 testing"
        ((CORE_COUNT++))
    elif [ $1 -eq 134 ]
    then
        echo "      >>> abort during $2 testing"
        ((CORE_COUNT++))
    elif [ $1 -eq 124 ]
    then
        echo "      >>> timeout during $2 testing"
    #else
        #echo "$1 is a okay"
    fi
    sync
}

chmodAndTimeStampFiles()
{
    #chmod a+r Constitution.txt Iliad.txt jargon.txt words.txt ?-s.txt
    chmod a+r Iliad.txt jargon.txt words.txt ?-s.txt
	chmod g+wr,o+r,u-w [0-9]-s.txt
	chmod a+rx *.bin
	chmod g+w random-333.bin
	chmod a-x zeroes-1M.bin
	chmod o-r zeroes-1M.bin
	chmod og-rw,g-x,o+r zeroes-4M.bin
	chmod g-r random-2M.bin
	#chmod a+rx zero-sized-file.bin
	touch -t 200110111213.14 text-5k.txt
	touch -t 197009011023.44 text-75k.txt
	touch -t 199912122358.59 words.txt
	#touch -t 197805082150.59 Constitution.txt Iliad.txt
    touch -t 197805082150.59 Iliad.txt
	touch -t 202112110217.44 jargon.txt
	touch -t 201202030405.06 zer*.bin
	touch -t 198012050303.06 ran*.bin
	touch -t 199507080910.36 [01]-s.txt
	touch -t 199608040311.36 [23]-s.txt
	touch -t 199706070809.36 [45]-s.txt
	touch -t 196003030303.03 6-s.txt
	touch -t 195701011532.57 zeroes-4M.bin
}

copyTestFiles()
{
	echo ""
	echo "  Copying test files into current directory"
    
    #rm -f ${PROG}.h
    #ln -s ${JDIR}/${PROG}.h .
    
    rm -f Constitution.txt Iliad.txt jargon.txt text-*k.txt words.txt
    rm -f random-*.bin
    rm -f zeroes-?M.bin zero-sized-file.bin
    rm -f [0-9]-s.txt

    cp ${JDIR}/*.txt .
    cp ${JDIR}/random-*.bin .
    cp ${JDIR}/zer* .
    #cp ${JDIR}/*.viktar .
    #cp ${JDIR}/[0-6]-s.txt .

    chmodAndTimeStampFiles

	#rm -f corruptTest?.${PROG} goodTest?.${PROG}
    rm -f ${PROG}_*_[JS].${PROG}
    rm -f ${PROG}_*_[JS].ar
    rm -f ${PROG}_*_[JS].{out,err}

    rm -f ${AR_PROG}_*_toc[12].{ar,stoc,diff} ${AR_PROG}_*_toc[12]_*.{ar,stoc,diff}


    chmodAndTimeStampFiles
    
	echo "    Test files copied. Permissions and dates set."

    sync ; sync ; sync
}

build()
{
    BuildFailed=0

    echo -e "\nBuilding ..."

    rm -f ${PROG}.h
    ln -s ${JDIR}/${PROG}.h .

    make clean > /dev/null 2> /dev/null
    make clean all 2> WARN.err > WARN.out
    RET=$?
    if [ ${RET} -ne 0 ]
    then
        echo "Build failed. Is 'make clean' broken?"
        BuildFailed=1
        return
    fi
    NUM_BYTES=$(wc -c < WARN.err)
    if [ ${NUM_BYTES} -eq 0 ]
    then
        echo "    You have no compiler warnings messages. Good job."
    else
        echo ">>> You have compiler warnings messages. That is -20 percent!"
        WARNINGS=1
    fi

    if [ ! -x ${PROG} ]
    then
        BuildFailed=1
    fi

    echo -e "Build done ..."
}

testHelp()
{
    echo "Testing help text ..."

    HELP_FILE=${RANDOM}_help
    ${SPROG} -h 2>&1 > ${PROG}_${HELP_FILE}_S.out
    ${JPROG} -h 2>&1 > ${PROG}_${HELP_FILE}_J.out

    ${DIFF} ${DIFF_OPTIONS} ${PROG}_${HELP_FILE}_S.out ${PROG}_${HELP_FILE}_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\thelp text is good"
    else
        echo ">>> help text needs help"
        echo "    https://www.youtube.com/watch?v=2Q_ZzBGPdqE"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${PROG}_${HELP_FILE}_S.out ${PROG}_${HELP_FILE}_J.out"
    fi

    echo "** Help text done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testTOC()
{
    echo "Testing TOC ..."

    TOC_FILE=${AR_PROG}_${RANDOM}_toc1
    ${AR_PROG} -cUr ${TOC_FILE}.${AR_PROG} [0-9]-s.txt

    ${AR_PROG} -t ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_ar1.stoc
    ${SPROG} -t -f ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_S1.stoc

    ${AR_PROG} -v -t ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_ar2.stoc
    ${SPROG} -t -f ${TOC_FILE}.${AR_PROG} -v  > ${TOC_FILE}_S2.stoc

    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_ar1.stoc ${TOC_FILE}_S1.stoc > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tsmall TOC non-determistic text is good"
    else
        echo ">>> help TOC non-determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_ar1.stoc ${TOC_FILE}_S1.stoc"
    fi

    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_ar2.stoc ${TOC_FILE}_S2.stoc > ${TOC_FILE}_diff2.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tverbose TOC non-determistic text is good"
    else
        echo ">>> verbose TOC non-determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_ar2.stoc ${TOC_FILE}_S2.stoc"
    fi

    
    TOC_FILE=${AR_PROG}_${RANDOM}_toc2
    ${AR_PROG} -cDr ${TOC_FILE}.${AR_PROG} [0-9]-s.txt

    ${AR_PROG} -t ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_ar1.stoc
    ${SPROG} -t -f ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_S1.stoc

    ${AR_PROG} -v -t ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_ar2.stoc
    ${SPROG} -t -f ${TOC_FILE}.${AR_PROG} -v  > ${TOC_FILE}_S2.stoc

    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_ar1.stoc ${TOC_FILE}_S1.stoc > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tsmall TOC determistic text is good"
    else
        echo ">>> help TOC determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_ar1.stoc ${TOC_FILE}_S1.stoc"
    fi

    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_ar2.stoc ${TOC_FILE}_S2.stoc > ${TOC_FILE}_diff2.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tverbose TOC determistic text is good"
    else
        echo ">>> verbose TOC determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_ar2.stoc ${TOC_FILE}_S2.stoc"
    fi


    echo "** TOC tests done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testCreateTextFiles()
{
    echo "Testing create text archives ..."

    local TEST_FAIL=0

    TOC_FILE=${AR_PROG}_${RANDOM}_text1
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU1.${AR_PROG} [0-9]-s.txt
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cUf ${TOC_FILE}_sprogU1.${PROG} [0-9]-s.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_arU1.${AR_PROG} ${TOC_FILE}_sprogU1.${PROG} > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tcreate text archive non-determistic text is good"
    else
        echo ">>> create text archive non-determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_arU1.${AR_PROG} ${TOC_FILE}_sprogU1.${PROG}"
    fi

    
    TOC_FILE=${AR_PROG}_${RANDOM}_text2
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU2.${AR_PROG} [0-9]-s.txt
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf ${TOC_FILE}_sprogU2.${PROG} [0-9]-s.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_arU2.${AR_PROG} ${TOC_FILE}_sprogU2.${PROG} > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tcreate text archive determistic text is good"
    else
        echo ">>> create text archive determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_arU2.${AR_PROG} ${TOC_FILE}_sprogU2.${PROG}"
    fi


    TOC_FILE=${AR_PROG}_${RANDOM}_text3
    chmodAndTimeStampFiles
    ${AR_PROG} -cDr ${TOC_FILE}_arD1.${AR_PROG} [0-9]-s.txt
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cDf ${TOC_FILE}_sprogD1.${PROG} [0-9]-s.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_arD1.${AR_PROG} ${TOC_FILE}_sprogD1.${PROG} > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tcreate text archive determistic text is good"
    else
        echo ">>> create text archive determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_arD1.${AR_PROG} ${TOC_FILE}_sprogD1.${PROG}"
    fi


    echo -e "\n\t** testing with longer list of files **\n"

    TOC_FILE=${AR_PROG}_${RANDOM}_text4
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU1.${AR_PROG} [0-9]-s.txt jargon.txt Iliad.txt text-5k.txt text-75k.txt words.txt
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cUf ${TOC_FILE}_sprogU1.${PROG} [0-9]-s.txt  jargon.txt Iliad.txt text-5k.txt text-75k.txt words.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_arU1.${AR_PROG} ${TOC_FILE}_sprogU1.${PROG} > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tcreate text archive non-determistic text is good"
    else
        echo ">>> create text archive non-determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_arU1.${AR_PROG} ${TOC_FILE}_sprogU1.${PROG}"
    fi

    
    TOC_FILE=${AR_PROG}_${RANDOM}_text5
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU2.${AR_PROG} [0-9]-s.txt jargon.txt Iliad.txt text-5k.txt text-75k.txt words.txt
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf ${TOC_FILE}_sprogU2.${PROG} [0-9]-s.txt jargon.txt Iliad.txt text-5k.txt text-75k.txt words.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_arU2.${AR_PROG} ${TOC_FILE}_sprogU2.${PROG} > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tcreate text archive determistic text is good"
    else
        echo ">>> create text archive determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_arU2.${AR_PROG} ${TOC_FILE}_sprogU2.${PROG}"
    fi


    TOC_FILE=${AR_PROG}_${RANDOM}_text6
    chmodAndTimeStampFiles
    ${AR_PROG} -cDr ${TOC_FILE}_arD1.${AR_PROG} [0-9]-s.txt jargon.txt Iliad.txt text-5k.txt text-75k.txt words.txt
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cDf ${TOC_FILE}_sprogD1.${PROG} [0-9]-s.txt jargon.txt Iliad.txt text-5k.txt text-75k.txt words.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ${DIFF} ${DIFF_OPTIONS} ${TOC_FILE}_arD1.${AR_PROG} ${TOC_FILE}_sprogD1.${PROG} > ${TOC_FILE}_diff1.diff 2>&1
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tcreate text archive determistic text is good"
    else
        echo ">>> create text archive determistic needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y ${TOC_FILE}_arD1.${AR_PROG} ${TOC_FILE}_sprogD1.${PROG}"
    fi

    
    echo "** create text archives tests done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testCreateBinFiles()
{
    echo "Testing create bin archives ..."

    BIN_FILES="random-333.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin1
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cUf ${TOC_FILE}_sprogU.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "1 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_arU.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprogU.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED single binary archive member, with -U ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single binary archive member, with -U ${BIN_FILES}\n\tPOINTS=${POINTS}"

    
    #################################################################################
    BIN_FILES="random-24M.bin random-2M.bin random-333.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin2
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cUf ${TOC_FILE}_sprogU.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "2 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_arU.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprogU.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED 3 archive binary members, with -U ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 3 archive binary members, with -U ${BIN_FILES}\n\tPOINTS=${POINTS}"
    
    #################################################################################
    BIN_FILES="1-s.txt random-24M.bin 2-s.txt random-2M.bin 3-s.txt random-333.bin 4-s.txt zeroes-1M.bin 5-s.txt zeroes-4M.bin 6-s.txt"

    TOC_FILE=${AR_PROG}_${RANDOM}_bin3
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_arU.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cUf ${TOC_FILE}_sprogU.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "3 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_arU.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprogU.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED 5 archive binary members, with -U ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 5 archive binary members, with -U ${BIN_FILES}\n\tPOINTS=${POINTS}"
    
    #################################################################################
    #################################################################################

    BIN_FILES="random-333.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin4
    chmodAndTimeStampFiles
    ${AR_PROG} -cDr ${TOC_FILE}_arD.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cDf ${TOC_FILE}_sprogD.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "4 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_arD.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprogD.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED single binary archive member, with -D ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single binary archive member, with -D ${BIN_FILES}\n\tPOINTS=${POINTS}"
    
    #################################################################################
    BIN_FILES="random-333.bin random-24M.bin random-2M.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin5
    chmodAndTimeStampFiles
    ${AR_PROG} -cDr ${TOC_FILE}_arD.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cDf ${TOC_FILE}_sprogD.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "5 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_arD.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprogD.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED 3 archive binary members, with -D ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 3 archive binary members, with -D ${BIN_FILES}\n\tPOINTS=${POINTS}"
    
    #################################################################################
    BIN_FILES="5-s.txt random-24M.bin 3-s.txt random-2M.bin 1-s.txt random-333.bin 2-s.txt zeroes-1M.bin 4-s.txt zeroes-4M.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin6
    chmodAndTimeStampFiles
    ${AR_PROG} -cDr ${TOC_FILE}_arD.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cDf ${TOC_FILE}_sprogD.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "6 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_arD.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprogD.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED 5 archive binary members, with -D ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 5 archive binary members, with -D ${BIN_FILES}\n\tPOINTS=${POINTS}"

    #################################################################################
    #################################################################################

    BIN_FILES="random-333.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin7
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_ar.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf ${TOC_FILE}_sprog.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "4 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_ar.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprog.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED single binary archive member, with ${BIN_FILES}  ${TOC_FILE}_ar.${AR_PROG} ${TOC_FILE}_sprog.${PROG}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single binary archive member, with ${BIN_FILES}\n\tPOINTS=${POINTS}"
    
    #################################################################################
    BIN_FILES="random-24M.bin random-333.bin random-2M.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin8
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_ar.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf ${TOC_FILE}_sprog.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "5 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_ar.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprog.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED 3 archive binary members, with ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 3 archive binary members, with ${BIN_FILES}\n\tPOINTS=${POINTS}"
    
    #################################################################################
    BIN_FILES="1-s.txt 2-s.txt random-24M.bin random-2M.bin 3-s.txt 5-s.txt random-333.bin 4-s.txt zeroes-1M.bin 6-s.txt zeroes-4M.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_bin9
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_ar.${AR_PROG} ${BIN_FILES}

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf ${TOC_FILE}_sprog.${PROG} ${BIN_FILES} 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "6 testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    ASUM=$(${SUM} ${TOC_FILE}_ar.${AR_PROG} | awk '{print $1;}')
    SSUM=$(${SUM} ${TOC_FILE}_sprog.${PROG} | awk '{print $1;}')
    if [ ${ASUM} != ${SSUM} ]
    then
        echo ">>> FAILED 5 archive binary members, with ${BIN_FILES}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 5 archive binary members, with ${BIN_FILES}\n\tPOINTS=${POINTS}"

    
    echo "** create bin archive tests done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testExtractTextFiles()
{
    echo "Testing extract from archive files..."

    chmodAndTimeStampFiles
    BIN_FILES="1-s.txt 2-s.txt random-24M.bin random-2M.bin 3-s.txt 5-s.txt random-333.bin 4-s.txt zeroes-1M.bin 6-s.txt zeroes-4M.bin"
    TOC_FILE=${AR_PROG}_${RANDOM}_exD1
    chmodAndTimeStampFiles
    ${AR_PROG} -cDr ${TOC_FILE}_ar.${AR_PROG} ${BIN_FILES}
    #${SPROG} -cDf ${TOC_FILE}_ar.${PROG} ${BIN_FILES}

    if [ -d ar_exD ]
    then
        rm -rf ar_exD
    fi
    mkdir ar_exD
    cd ar_exD
    rm -f *.[ar,arvik]
    ln -fs ../${TOC_FILE}_ar.${AR_PROG} .
    ${AR_PROG} -x ${TOC_FILE}_ar.${AR_PROG}
    ls -l ${BIN_FILES} | awk '{print $1, $2, $3, $4, $5, $9;}' > ${TOC_FILE}_ar.ls
    cd ..

    #################

    if [ -d arvik_exD ]
    then
        rm -rf arvik_exD
    fi
    mkdir arvik_exD
    cd arvik_exD
    rm -f *.[ar,arvik]
    ln -fs ../${TOC_FILE}_ar.${AR_PROG} .
    #${SPROG} -f ${TOC_FILE}_ar.${AR_PROG} -x
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -f ${TOC_FILE}_ar.${AR_PROG} -x 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "1 testing extract archive files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    ls -l ${BIN_FILES} | awk '{print $1, $2, $3, $4, $5, $9;}' > ${TOC_FILE}_arvik.ls
    cd ..

    ${DIFF} ${DIFF_OPTIONS} ar_exD/${TOC_FILE}_ar.ls arvik_exD/${TOC_FILE}_arvik.ls > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tPassed extract archive members, with -D\n\tPOINTS=${POINTS}"
    else
        echo ">>> FAILED extract archive member, with -D"
        echo ">>> Fix this before trying more tests"
    fi

    ################################################################################
    ################################################################################

    chmodAndTimeStampFiles
    #BIN_FILES="1-s.txt 2-s.txt random-24M.bin random-2M.bin 3-s.txt 5-s.txt random-333.bin 4-s.txt zeroes-1M.bin 6-s.txt zeroes-4M.bin"
    BIN_FILES="1-s.txt 2-s.txt 3-s.txt 5-s.txt 4-s.txt 6-s.txt"
    TOC_FILE=${AR_PROG}_${RANDOM}_exU1
    chmodAndTimeStampFiles
    ${AR_PROG} -cUr ${TOC_FILE}_ar.${AR_PROG} ${BIN_FILES}
    #${SPROG} -cUf ${TOC_FILE}_ar.${PROG} ${BIN_FILES}

    if [ -d ar_exU ]
    then
        rm -rf ar_exU
    fi
    mkdir ar_exU
    cd ar_exU
    rm -f *.[ar,arvik]
    ln -fs ../${TOC_FILE}_ar.${AR_PROG} .
    ${AR_PROG} -xo ${TOC_FILE}_ar.${AR_PROG}
    #ls -l ${BIN_FILES} | awk '{print $1, $2, $3, $4, $5, $9;}' > ${TOC_FILE}_ar.ls
    ls -l ${BIN_FILES} > ${TOC_FILE}_ar.ls
    cd ..

    #################

    if [ -d arvik_exU ]
    then
        rm -rf arvik_exU
    fi
    mkdir arvik_exU
    cd arvik_exU
    rm -f *.[ar,arvik]
    ln -fs ../${TOC_FILE}_ar.${AR_PROG} .
    #${SPROG} -f ${TOC_FILE}_ar.${AR_PROG} -x
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -f ${TOC_FILE}_ar.${AR_PROG} -x 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "1 testing extract archive files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    #ls -l ${BIN_FILES} | awk '{print $1, $2, $3, $4, $5, $9;}' > ${TOC_FILE}_arvik.ls
    ls -l ${BIN_FILES} > ${TOC_FILE}_arvik.ls
    cd ..

    ${DIFF} ${DIFF_OPTIONS} ar_exU/${TOC_FILE}_ar.ls arvik_exU/${TOC_FILE}_arvik.ls > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        ((POINTS+=${POINTS_PER_TEST}))
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tPassed extract archive members, with -U\n\tPOINTS=${POINTS}"
    else
        echo ">>> FAILED extract archive member, with -U"
        echo ">>> Fix this before trying more tests"
    fi

    
    echo "** extract from archive file passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testBadFile()
{
    echo "Testing bad file detect..."    

    chmodAndTimeStampFiles
    TOC_FILE=${AR_PROG}_${RANDOM}_b1
    CORRUPT_FILE=${TOC_FILE}.${AR_PROG}
    ${AR_PROG} -crD JUNK.${AR_PROG} [1-9]-s.txt
    sed -e 's/!<arch>/!<ARCH>/1' JUNK.${AR_PROG} > ${CORRUPT_FILE}

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -tvf ${CORRUPT_FILE} 1> ${TOC_FILE}.out  2> ${TOC_FILE}.err " ; }
    CORE_DUMP=$?
    #echo "exit value: ${CORE_DUMP}"
    coreDumpMessage ${CORE_DUMP} "1 testing bad file detect..."
    if [ ${CORE_DUMP} -gt 100 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    if [ ${CORE_DUMP} -eq 8 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tPassed bad file detect 1\n\tPOINTS=${POINTS}"
    else
        echo ">>> FAILED bad file detect 1"
    fi

    ##############################################################
    
    #chmodAndTimeStampFiles
    TOC_FILE=${AR_PROG}_${RANDOM}_b2
    CORRUPT_FILE=${TOC_FILE}.${AR_PROG}
    #${AR_PROG} -crD JUNK.${AR_PROG} [1-9]-s.txt
    sed -e 's/!<arch>/!<archimedes>/1' JUNK.${AR_PROG} > ${CORRUPT_FILE}

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -tvf ${CORRUPT_FILE} 1> ${TOC_FILE}.out  2> ${TOC_FILE}.err " ; }
    CORE_DUMP=$?
    #echo "exit value: ${CORE_DUMP}"
    coreDumpMessage ${CORE_DUMP} "2 testing bad file detect..."
    if [ ${CORE_DUMP} -gt 100 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    if [ ${CORE_DUMP} -eq 8 ]
    then
        ((POINTS+=${POINTS_PER_TEST}))
        echo -e "\tPassed bad file detect 2\n\tPOINTS=${POINTS}"
    else
        echo ">>> FAILED bad file detect 2"
    fi


    rm -f JUNK.${PROG}
    
    echo "** bad file detect passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testValgrind()
{
    echo "Testing with valgrind for memory leaks..."

    TOC_FILE=${AR_PROG}_${RANDOM}_val1
    ${AR_PROG} -cUr ${TOC_FILE}.${AR_PROG} [0-9]-s.txt
    
    ${VALGRIND} ${SPROG} -t -f ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_v1.out 2> ${TOC_FILE}_v1.err
    LEAKS=$(grep "${NOLEAKS}" ${TOC_FILE}_v1.err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 1 ]
    then
        echo -e "\tNo leaks found in short TOC. Excellent."
    else
        echo ">>> Leaks found in short TOC."
        LEAKS_FOUND=1
        CLEANUP=0
    fi

    TOC_FILE=${AR_PROG}_${RANDOM}_val2
    ${VALGRIND} ${SPROG} -tvf ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_v1.out 2> ${TOC_FILE}_v1.err
    LEAKS=$(grep "${NOLEAKS}" ${TOC_FILE}_v1.err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 1 ]
    then
        echo -e "\tNo leaks found in long TOC. Excellent."
    else
        echo ">>> Leaks found in long TOC."
        LEAKS_FOUND=1
        CLEANUP=0
    fi

    TOC_FILE=${AR_PROG}_${RANDOM}_val3
    ${VALGRIND} ${SPROG} -cf ${TOC_FILE}.${AR_PROG} ?-s.txt > ${TOC_FILE}_v2.out 2> ${TOC_FILE}_v2.err
    LEAKS=$(grep "${NOLEAKS}" ${TOC_FILE}_v2.err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 1 ]
    then
        echo -e "\tNo leaks found in create. Excellent."
    else
        echo ">>> Leaks found in create."
        LEAKS_FOUND=1
        CLEANUP=0
    fi

    if [ -d arvik_val ]
    then
        rm -rf arvik_val
    fi
    mkdir arvik_val
    cd arvik_val
    ln -fs ../${TOC_FILE}.${AR_PROG} . 
    ${VALGRIND} ${SPROG} -xf ${TOC_FILE}.${AR_PROG} > ${TOC_FILE}_v3.out 2> ${TOC_FILE}_v3.err
    LEAKS=$(grep "${NOLEAKS}" ${TOC_FILE}_v3.err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 1 ]
    then
        echo -e "\tNo leaks found in extract. Excellent."
    else
        echo ">>> Leaks found in extract."
        LEAKS_FOUND=1
        CLEANUP=0
    fi
    cd ..

    
    echo "** Done with Testing valgrind."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

cleanTestFiles()
{
    if [ ${CLEANUP} -eq 1 ]
    then
        echo "Cleaning up test files"
        
        rm -f Constitution.txt Iliad.txt jargon.txt text-*k.txt words.txt
        rm -f [0-9]-s.txt NOTES.txt WARN.out
        rm -f random-*.bin
        rm -f zeroes-?M.bin zero-sized-file.bin

        rm -f ${PROG}_*_[JS].${PROG}
        rm -f ${PROG}_*_[JS].ar
        rm -f ${PROG}_*_[JS].{out,err}

        rm -f valgrindTest*.err WARN.err validate*.err

        rm -f ${AR_PROG}_*_toc[12].{ar,stoc,diff} ${AR_PROG}_*_toc[12]_*.{ar,stoc,diff}
        rm -f ${AR_PROG}_*_text[1-9]_*.{ar,stoc,diff,arvik}

        rm -f ar_*_bin[0-9]_ar*.ar ar_*_bin[0-9]_sprog*.arvik

        rm -rf ar_exD arvik_exD ar_exU arvik_exU arvik_val
        rm -f *.${AR_PROG} *.${PROG} *.out *.err

        ln -fs ${JDIR}/${PROG}.h .

        make clean 1> /dev/null 2> /dev/null
    else
        echo "Skipping cleanup"
    fi
}


while getopts "xChl" opt
do
    case $opt in
        x)
            # If you really, really, REALLY want to watch what is going on.
            echo "Hang on for a wild ride."
            set -x
            ;;
        C)
            # Skip removal of data files
            CLEANUP=0
            ;;
        h)
            echo "$0 [-h] [-C] [-x]"
            echo "  -h  Display this amazing help message"
            echo "  -C  Do not remove all the test files"
            echo "  -x  Show LOTS and LOTS and LOTS of text about what is happening"
            echo "  -l  When used with -x, line numbers are prefixed to diagnostic output"
            exit 0
            ;;
        l)
            PS4='Line ${LINENO}: '
            ;;
        \?)
            echo "Invalid option" >&2
            echo ""
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

HOST=$(hostname -s)
if [ ${HOST} != ${FILE_HOST} ]
then
    echo "This script MUST be run on ${FILE_HOST}"
    exit 1
fi

BDATE=$(date)

build
if [ ${BuildFailed} -ne 0 ]
then
    echo "Since the program build failed (using make), ending test"
    echo "Points = 0"
    exit 1
else
    echo "Build success!"
fi

trap 'signalCaught;' SIGTERM SIGQUIT SIGKILL SIGSEGV
trap 'signalCtrlC;' SIGINT
#trap 'signalSegFault;' SIGCHLD

rm -f test_[0-9][1-9]_[JS].{${PROG},ar}


copyTestFiles

testHelp

testTOC


testCreateTextFiles

testCreateBinFiles

testExtractTextFiles

testBadFile

testValgrind

cleanTestFiles


EDATE=$(date)

echo -e "\n\n*********************************************************"
echo "*********************************************************"
echo "Done with Testing."
echo "Points so far ${POINTS} of ${TOTAL_POINTS}"
echo "This does not include the points from the Makefile-test.bash script"
if [ ${LEAKS_FOUND} -ne 0 ]
then
    echo -e "\n**** But.... Memory leaks were found. That is a 20% deduction. ****"
    POINTS=$(echo ${POINTS} | awk '{print $1 * 0.8;}')
    echo "Points with leak deductions ${POINTS} of ${TOTAL_POINTS}"
    echo -e "OUCH!!! That hurts! Where is my leak detector?\n"
fi

if [ ${WARNINGS} -ne 0 ]
then
    echo -e "\n**** But.... Compiler warnings were found. That is a 20% deduction. ****"
    POINTS=$(echo ${POINTS} | awk '{print $1 * 0.8;}')
    echo "Points with compiler warning deductions ${POINTS} of ${TOTAL_POINTS}"
    echo -e "OUCH!!! That hurts! Where is that compiler warnings fixer-upper?\n"
fi
echo "This does not take into account any late penalty that may apply."

echo -e "\n"
echo "Test begun at     ${BDATE}"
echo "Test completed at ${EDATE}"
echo -e "\n"
echo "+++ TOTAL_POINTS    = ${POINTS} of ${TOTAL_POINTS} ***"
