#!/bin/bash

# Check for required commands
if ! command -v xmllint >/dev/null || ! command -v espeak >/dev/null; then
    echo "This script requires 'xmllint' and 'espeak' to be installed."
    exit 1
fi

# Function to speak with a delay
speak() {
    for line in "$@"; do
        espeak "$line" -s 120 -p 50
        sleep 1  # Pause for 1 second before the next command
    done
}

# Read poses from the XML file
POSES=$(xmllint --xpath '//pose/name/text()' yoga_poses.xml)
DESCRIPTIONS=$(xmllint --xpath '//pose/description/text()' yoga_poses.xml)
DIFFICULTIES=$(xmllint --xpath '//pose/difficulty/text()' yoga_poses.xml)
TARGETED_MUSCLES=$(xmllint --xpath '//pose/targetedMuscles/text()' yoga_poses.xml)

# Combine the names, descriptions, difficulties, and targeted muscles into arrays
IFS=$'\n' read -d '' -r -a names <<< "$POSES"
IFS=$'\n' read -d '' -r -a descriptions <<< "$DESCRIPTIONS"
IFS=$'\n' read -d '' -r -a difficulties <<< "$DIFFICULTIES"
IFS=$'\n' read -d '' -r -a targetedMuscles <<< "$TARGETED_MUSCLES"

# Check if all arrays match in count
if [ ${#names[@]} -ne ${#descriptions[@]} ] || [ ${#names[@]} -ne ${#difficulties[@]} ] || [ ${#names[@]} -ne ${#targetedMuscles[@]} ]; then
    echo "Mismatch between the number of names, descriptions, difficulties, and targeted muscles."
    exit 1
fi

# Get user input for skill level
echo "Select your skill level: (1) Novice, (2) Intermediate, (3) Advanced"
read -r skill_level

# Get total workout time limit
echo "Enter total workout time in seconds:"
read -r total_time

# Initialize variables for selected poses, constraints, and muscle group tracking
selected_poses=()
hold_time=0
pose_count=0
muscle_group_time=()  # Associative array (declare as an indexed array)
muscle_group_total_time=()  # For tracking total time spent on each muscle group

# Define muscle groups for tracking
declare -A muscle_groups_mapping

# Determine the hold time and maximum poses per skill level
case $skill_level in
    1) 
        hold_time=5  # seconds for novice
        max_intermediate=1  # max intermediate poses for novice
        max_advanced=0
        ;;
    2)
        hold_time=7  # seconds for intermediate
        max_intermediate=0
        max_advanced=2  # max advanced poses for intermediate
        ;;
    3)
        hold_time=7  # seconds for advanced
        max_intermediate=0
        max_advanced=0
        ;;
    *)
        echo "Invalid selection. Please restart and select 1, 2, or 3."
        exit 1
        ;;
esac

# Combine all the poses into a single array for randomization
all_poses=()
for i in "${!names[@]}"; do
    all_poses+=("$i")  # Store the indices for randomization
done

# Shuffle the poses
shuffled_indices=($(shuf -e "${all_poses[@]}"))  # Shuffle the indices

# Loop through poses until total time is reached
elapsed_time=0

# Add poses based on shuffled order
while [[ $elapsed_time -lt $total_time ]]; do
    for idx in "${shuffled_indices[@]}"; do
        pose="${names[idx]}"
        description="${descriptions[idx]}"
        difficulty="${difficulties[idx]}"
        muscles="${targetedMuscles[idx]}"

        # Add poses based on user skill level
        if [[ $skill_level -eq 1 && $difficulty == "Beginner" ]]; then
            selected_poses+=("$pose" "$description" "$muscles")
        elif [[ $skill_level -eq 1 && $difficulty == "Intermediate" && pose_count -lt max_intermediate ]]; then
            selected_poses+=("$pose" "$description" "$muscles")
            pose_count=$((pose_count + 1))
        elif [[ $skill_level -eq 2 && $difficulty == "Beginner" ]]; then
            selected_poses+=("$pose" "$description" "$muscles")
        elif [[ $skill_level -eq 2 && $difficulty == "Intermediate" ]]; then
            selected_poses+=("$pose" "$description" "$muscles")
        elif [[ $skill_level -eq 2 && $difficulty == "Advanced" && pose_count -lt max_advanced ]]; then
            selected_poses+=("$pose" "$description" "$muscles")
            pose_count=$((pose_count + 1))
        elif [[ $skill_level -eq 3 ]]; then
            selected_poses+=("$pose" "$description" "$muscles")
        fi
    done

    # Speak and hold poses
    for ((i = 0; i < ${#selected_poses[@]}; i+=3)); do
        pose="${selected_poses[i]}"
        description="${selected_poses[i+1]}"
        muscles="${selected_poses[i+2]}"

        # Speak the pose name
        speak "$pose"

        # Speak the description if needed
        if [[ $skill_level -eq 1 || $skill_level -eq 2 && ${pose_count} -eq 0 ]]; then
            speak "$description"
        fi

        # Track muscle groups
        for muscle in $(echo $muscles | tr ',' ' '); do
            muscle_groups_mapping["$muscle"]=1  # Initialize muscle group key to count time
            muscle_group_time["$muscle"]=$((hold_time + ${muscle_group_time["$muscle"]:-0}))  # Add time spent
        done

        # Hold the pose for the specified amount of time
        sleep "$hold_time"
        
        # Increment total elapsed time
        elapsed_time=$((elapsed_time + hold_time))

        # Break if total time exceeded
        if [[ $elapsed_time -ge $total_time ]]; then
            break
        fi
    done
done
