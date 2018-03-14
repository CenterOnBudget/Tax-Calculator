# Execute validation TEST using Tax-Calculator SimpleTaxIO class as follows:
# (1) generate a random sample of tax filing units (INPUT),
# (2) generate OUTPUT from INPUT and REFORM using simtax.py, and
# (3) generate tax-difference tabulations by comparing OUTPUT with output
#     file generated by Internet-TAXSIM using the same INPUT and REFORM.
# Check command-line arguments
if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
    echo "ERROR: number of command-line arguments not in 2-to-3 range"
    echo "USAGE: bash test.sh LYY REFORM [save]"
    echo "       WHERE L is a letter that is valid taxsim_in.tcl L input and"
    echo "             YY is valid taxsim_in.tcl CALENDAR YEAR (20YY) input.;"
    echo "       WHERE REFORM is Internet-TAXSIM option (e.g., '50_1') or"
    echo "             '.' for no reform (i.e., current-law policy);"
    echo "       WHERE the 'save' option skips the deletion of INPUT and"
    echo "             OUTPUT files at the end of the test"
    touch testerror
    exit 1
fi
LYY=$1
REFORM=$2
SAVE=false
if [[ "$#" -eq 3 ]]; then
    if [[ "$3" == "save" ]]; then
        SAVE=true
    else
        echo "ERROR: optional third command-line argument must be 'save'"
        echo "USAGE: bash test.sh LYY REFORM [save]"
        touch testerror
        exit 1
    fi
fi
# Generate specified INPUT file
L=${LYY:0:1}    
YY=${LYY:1:2}
tclsh taxsim_in.tcl 20$YY $L > $LYY.in
# Generate simtax.py OUTPUT for specified INPUT and REFORM
if [[ "$REFORM" == "." ]] ; then
    python ../../../simtax.py --taxsim2441 $LYY.in
    SUFFIX=""
    OVAR4=""
else
    RJSON="reform-$REFORM.json"
    python ../../../simtax.py --taxsim2441 --reform $RJSON $LYY.in
    SUFFIX="-reform-$REFORM"
    OVAR4="--ovar4"
fi
# Unzip Internet-TAXSIM output for specified INPUT and REFORM
unzip -oq output-taxsim.zip $LYY.in.out-taxsim$SUFFIX
# Compare simtax and Internet-TAXSIM OUTPUT
tclsh taxdiffs.tcl $OVAR4 $LYY.in.out-simtax$SUFFIX \
                          $LYY.in.out-taxsim$SUFFIX > $LYY$SUFFIX.taxdiffs
RC=$?
if [ $RC -ne 0 ]; then
   exit $RC
fi
# Check for difference between actual .taxdiffs and expected .taxdiffs files
DIR="taxsim"
RC=0
DIFF=$(git diff --name-status $LYY$SUFFIX.taxdiffs)
if [[ "$DIFF" != "" ]] ; then
    RC=1
    touch testerror
    DIF=${DIFF/M/F}
    RED=$(tput setaf 1)
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
    printf "$BOLD$RED$DIF$NORMAL\n"
else
    printf ". $DIR/$LYY$SUFFIX\n"
fi
# Remove temporary files
if [[ "$SAVE" == false ]] ; then
    rm -f $LYY.in $LYY.in.out-simtax$SUFFIX $LYY.in.out-taxsim$SUFFIX
fi
exit $RC
