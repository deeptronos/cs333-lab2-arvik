# Catherine Nemec



CC = gcc
DEFINES =
DEBUG = -g3 -O0
#WERROR = -Werror -Wextra
CFLAGS = $(DEFINES) $(DEBUG) -Wall -Wextra -Wshadow -Wunreachable-code -Wredundant-decls -Wmissing-declarations -Wold-style-definition -Wmissing-prototypes -Wdeclaration-after-statement -Wno-return-local-addr -Wunsafe-loop-optimizations -Wuninitialized -g #-v
COMMENT = "This is a comment, not a comet"
PERMS = og-rx

PROG1 = arvik
PROG2 =
PROG3 =
PROGS = $(PROG1)
 
all: $(PROGS)

arvik: arvik.o
	$(CC) $(CFLAGS) -o arvik arvik.o
	# chmod $(PERMS) arvik
# arvik.o:

# $(PROG1): $(PROG1).o
# 	$(CC) $(CFLAGS) -o $(PROG1) $(PROG1).o
# 	chmod $(PERMS) $(PROG1)

# $(PROG1).o: $(PROG1).c $(PROG1).h
# 	$(CC) $(CFLAGS) -c $(PROG1).c

# hellofunc.o: hellofunc.c $(PROG1).h
# 	$(CC) $(CFLAGS) -c hellofunc.c


# $(PROG2): $(PROG2).o
# 	$(CC) $(CFLAGS) -o $(PROG2) $(PROG2).o
# 	chmod $(PERMS) $(PROG2)

# $(PROG2).o: $(PROG2).c
# 	$(CC) $(CFLAGS) -c $(PROG2).c

# $(PROG3): $(PROG3).o
# 	$(CC) $(CFLAGS) -o $(PROG3) $(PROG3).o
# 	chmod $(PERMS) $(PROG3)

# $(PROG3).o: $(PROG3).c
# 	$(CC) $(CFLAGS) -c $(PROG3).c

%.o: %.c
	$(CC) $(CFLAGS) $< -c -o $@

clean cls:
	rm -f $(PROGS) *.o *~ \#*

# https://www.youtube.com/watch?v=LHQETlv-uZs
ci chicka boom:
	if [ ! -d RCS ] ; then mkdir RCS; fi
	ci -t-none -l -m"Chicka Chicka Boom Boom - checkin" [Mm]akefile *.[ch]

# https://www.youtube.com/watch?v=4m48GqaOz90
gotta git gat:
	if [ ! -d .git ] ; then git init; fi
	git add *.[ch] ?akefile
	git commit -m "The Black Eyed Peas - check in"

TAR_FILE = ${LOGNAME}_$(PROG1).tar.gz
tar:
	rm -f $(TAR_FILE)
	tar cvaf $(TAR_FILE) *.[ch] [Mm]akefile
	tar tvaf $(TAR_FILE)

comment:
	echo $(COMMENT)

opt:
	make clean
	make DEBUG=-O
