#! /bin/bash



FOLDER="LogAutomationDeleter"


folderfind=$(find /tmp -maxdepth 1 -name "$FOLDER" -type d -printf 1 -quit)
folderfind=${folderfind:-0}

if [ "$folderfind" != "1" ]; then
    mkdir -p /tmp/"$FOLDER"
else
    echo "Directory already created."
fi


run_or_handle_error() {
    "$@"
    local status=$?
    show_error_if_failed "$status" "$*"
    return "$status"
}

show_error_if_failed() {
    local status=$1
    local desc=$2
    if [ "$status" -ge 128 ]; then
        whiptail --title "Error Message" --msgbox "There was a serious error when running the option. Error: command failed with exit code $status: $desc" 8 78
    elif [ "$status" -ne 0 ]; then
        whiptail --title "Error Message" --msgbox "Error: command failed with exit code $status: $desc" 8 78
    fi
    return "$status"
}



# Main Menu for the SysAdmin Deleter

while true; do

CHOICE=$(whiptail --title "SysAdmin Log" --menu "Choose an option" 25 78 16 \
"Quit" "Quit the application" \
"1" "Show all of the logs files." \
"2" "Truncate a specific log file." \
"3" "Truncate all of the files." \
"4" "Check/Edit /etc/logrotate.d/logrotate.conf" \
"5" "Show disk usage of the logs" \
"6" "View the last n lines of systemd journal messages" \
"7" "View the last n lines of a unit journal messages" \
"8" "Filter journal messages within a time range" \
"9" "Filter unit journal messages within a time range" \
"10" "Show journal disk usage" \
"11" "Search a pattern in a specific log file" \
"12" "Check the status of a service" \
3>&1 1>&2 2>&3 )


exitstatus=$?


FILESINFO=$(ls -I "*.gz" -lh /var/log)


if [[ "$CHOICE" = "Quit" || "$exitstatus" != 0 ]]; then

    echo "See you later!"
    break

elif [ "$CHOICE" = "1" ]; then

    whiptail --title "/var/log Directory" --scrolltext --msgbox "$FILESINFO" 35 88 3>&1 1>&2 2>&3

elif [ "$CHOICE" = "2" ]; then

    FILESCHOSEN=$(whiptail --inputbox "Enter the files you would like to truncate: " 8 39 --title "File to truncate" 3>&1 1>&2 2>&3 )
    
    exitstatus=$?

    if [ "$exitstatus" = 0 ]; then

        if whiptail --title "File to truncate" --yesno "This option carries a lot of risk, are you sure you want to continue?" 8 78; then
            
            output=$(sudo find /var/log -name "$FILESCHOSEN" -printf 1 -quit)

            if [ "$output" -eq 1 ]; then
                run_or_handle_error sudo find /var/log -name "$FILESCHOSEN" -mmin +30 -exec truncate -s 0 {} \;
            else 
                echo "File not found or was updated in the last 30 min."
            fi
        else
            echo "User selected No, exit status was $?."
        fi
        
    else
        echo "User selected Cancel"
    fi

elif [ "$CHOICE" = "3" ]; then

        if whiptail --title "File to truncate" --yesno "This option carries a lot of risk, are you sure you want to continue?" 8 78; then
            run_or_handle_error sudo find /var/log -mmin +30 -exec truncate -s 0 {} \;
        else
            echo "User selected No, exit status was $?."
        fi
    
    
elif [ "$CHOICE" = "4" ]; then

    CONTENT=$(run_or_handle_error cat /etc/logrotate.d/logrotate.conf)

    if whiptail --scrolltext --yesno "$CONTENT" 35 78 --yes-button "Edit" --no-button "Cancel"; then
        run_or_handle_error sudo nano /etc/logrotate.d/logrotate.conf
    else 
        echo "User selected Cancel, exit status was $?."
    fi


elif [ "$CHOICE" = "5" ]; then

    run_or_handle_error sudo du -ah /var/log | sort -hr > /tmp/"$FOLDER"/disk_usage

    whiptail --scrolltext --textbox /tmp/"$FOLDER"/disk_usage 35 78

elif [ "$CHOICE" = "6" ]; then

    LINESCHOSEN=$(whiptail --inputbox "Enter the last n of lines to see: "  8 39 3>&1 1>&2 2>&3 )

    exitstatus=$?


    if [[ "$LINESCHOSEN" =~ ^[0-9]+$  && "$exitstatus" = 0 ]]; then
         run_or_handle_error sudo journalctl -n "$LINESCHOSEN" | less
    else
        echo "User selected Cancel."
    fi

elif [ "$CHOICE" = "7" ]; then

    CHOSENUNIT=$(whiptail --inputbox "What Unit you want to check?" 8 39 3>&1 1>&2 2>&3 )

    exitstatus=$?

    if [ "$exitstatus" = 0 ]; then
        LINESCHOSEN=$(whiptail --inputbox "Enter the last n of lines to see: "  8 39 3>&1 1>&2 2>&3 )

        run_or_handle_error sudo journalctl -n "$LINESCHOSEN" -u "$CHOSENUNIT"
    else
        echo "User selected Cancel."
    fi    

elif [ "$CHOICE" = "8" ]; then

    DATE1=$(whiptail --inputbox "Enter the time beggining time: " 8 39 "YYYY-MM-DD HH:MM:SS" 3>&1 1>&2 2>&3)

    DATE2=$(whiptail --inputbox "Enter the time ending time: " 8 39 "YYYY-MM-DD HH:MM:SS" 3>&1 1>&2 2>&3)

    exitstatus=$?

    if [ "$exitstatus" = 0 ]; then
        run_or_handle_error sudo journalctl -S "$DATE1" -U "$DATE2"

    else
        echo "User selected Cancel."
    fi    

elif [ "$CHOICE" = "9" ]; then

    CHOSENUNIT=$(whiptail --inputbox "What Unit you want to check?" 8 39 3>&1 1>&2 2>&3 )

    DATE1=$(whiptail --inputbox "Enter the time beggining time: " 8 39 "YYYY-MM-DD HH:MM:SS" 3>&1 1>&2 2>&3)

    DATE2=$(whiptail --inputbox "Enter the time ending time: " 8 39 "YYYY-MM-DD HH:MM:SS" 3>&1 1>&2 2>&3)

    exitstatus=$?

    if [ "$exitstatus" = 0 ]; then

        run_or_handle_error sudo journalctl -u "$CHOSENUNIT" -S "$DATE1" -U "$DATE2" > /tmp/"$FOLDER"/journalinfo

        status=$?

        if [ "$status" -ne 0 ]; then
            whiptail --title "Error" --msgbox "An error has ocurred (exit code $status)" 8 78
        else
            whiptail --scrolltext --textbox journalinfo 35 78
        fi

    else
        echo "User selected Cancel."
    fi


elif [ "$CHOICE" = "10" ]; then  

    run_or_handle_error journalctl --disk-usage > /tmp/"$FOLDER"/disk_usage_journal
    

    whiptail --scrolltext --textbox /tmp/"$FOLDER"/disk_usage_journal 10 60

elif [ "$CHOICE" = "11" ]; then

    LOGFILE=$(whiptail --inputbox "What is Log file you want to search?" 8 39 --title "Log File" 3>&1 1>&2 2>&3)
    PATTERN=$(whiptail --inputbox "What is the pattern you want to search?" 8 39 --title "Pattern in Log File" 3>&1 1>&2 2>&3)

    exitstatus=$?


   if [ "$exitstatus" = 0 ]; then

        LOGFILE=$(basename -- "$LOGFILE")
        resolved=$(realpath -e "/var/log/$LOGFILE" 2>/dev/null)

        if [[ "$resolved" != /var/log/* ]]; then
            whiptail --title "Error" --msgbox "Access outside /var/log is not allowed." 8 78
        else
            grep -- "$PATTERN" "$resolved" > /tmp/"$FOLDER"/grep_output 2>&1
            status=$?

            if [ "$status" -ne 0 ]; then
                whiptail --title "Error" --msgbox "No matches found or error occurred (exit code $status)" 8 78
            else
                whiptail --scrolltext --title "Matches for '$PATTERN' in $LOGFILE" --textbox /tmp/"$FOLDER"/grep_output 35 78
            fi
        fi
    else
        echo "User selected Cancel."
    fi

elif [ "$CHOICE" = "12" ]; then

     CHOSENUNIT=$(whiptail --inputbox "What Unit you want to check?" 8 39 3>&1 1>&2 2>&3 )

     exitstatus=$?

     if [ "$exitstatus" = 0 ]; then
        run_or_handle_error sudo systemctl status "$CHOSENUNIT"
    else
        echo "User selected Cancel."
    fi


fi

done