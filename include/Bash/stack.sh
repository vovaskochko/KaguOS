# This file contains functionality for stack handling and function calls

# Clean the main frame addresses with variables
function clear_main_frame {
    write_to_address ${GLOBAL_DISPLAY_ADDRESS} ""
    write_to_address ${GLOBAL_INPUT_ADDRESS} ""
    write_to_address ${GLOBAL_ARG1_ADDRESS} ""
    write_to_address ${GLOBAL_ARG2_ADDRESS} ""
    write_to_address ${GLOBAL_OUTPUT_ADDRESS} ""
    write_to_address ${GLOBAL_NEXT_CMD_ADDRESS} ""
}

# Move current main frame to stack and clear main frame area
function push_frame {
    local CURRENT_FRAME_COUNT=$(read_from_address ${GLOBAL_CURRENT_FRAME_COUNT_ADDRESS})
    # We have 3 lines of extra information for debugging
    # TODO
    #     1. In this code we are using constant value for frame size while in real life stack size differs
    #        from function to function as local variables used in function are stored in stack.
    #        While every function has a fixed size of stack known at the compilation time
    #        What changes should be done to support dynamical stack size in KaguOS code?
    #     2. Try to implement such an approach in KaguOS.
    local CUR_FRAME_SIZE=$(($GLOBAL_FRAME_SIZE + 3))

    local FRAME_END_ADDRESS=$(( $GLOBAL_CURRENT_FRAME_COUNT_ADDRESS - 2 - ($CUR_FRAME_SIZE * $CURRENT_FRAME_COUNT) ))
    local FRAME_START_ADDRESS=$(( $FRAME_END_ADDRESS + 1 - $CUR_FRAME_SIZE ))

    # Let's write frame header with a frame id at the frame start:
    write_to_address ${FRAME_START_ADDRESS} "=======START FRAME #:"
    write_to_address $(($FRAME_START_ADDRESS + 1)) "${CURRENT_FRAME_COUNT}"
    # Let's write frame footer at the frame end:
    write_to_address ${FRAME_END_ADDRESS} "=======END FRAME!"

    copy_from_to_n_address ${GLOBAL_MAIN_FRAME_START_ADDRESS} $(($FRAME_START_ADDRESS + 2)) ${GLOBAL_FRAME_SIZE}

    # increment frame counter
    cpu_execute "${CPU_INCREMENT_CMD}" ${GLOBAL_CURRENT_FRAME_COUNT_ADDRESS}
    copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_CURRENT_FRAME_COUNT_ADDRESS}

    clear_main_frame
}

# Move the top frame from the stack to main frame
function pop_frame {
    local CURRENT_FRAME_COUNT=$(read_from_address ${GLOBAL_CURRENT_FRAME_COUNT_ADDRESS})

    if [[ $CURRENT_FRAME_COUNT -eq 0 ]]; then
        exit_fatal "trying to pop element from empty frame. Kernel will be terminated!"
    fi

    # We have 3 lines of extra information for debugging
    local CURRENT_FRAME_SIZE=$(($GLOBAL_FRAME_SIZE + 3))

    local FRAME_START=$(($GLOBAL_CURRENT_FRAME_COUNT_ADDRESS - 1 - ($CURRENT_FRAME_COUNT * $CURRENT_FRAME_SIZE) ))

    # decrement frame counter
    cpu_execute "${CPU_DECREMENT_CMD}" ${GLOBAL_CURRENT_FRAME_COUNT_ADDRESS}
    copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_CURRENT_FRAME_COUNT_ADDRESS}

    copy_from_to_n_address $(($FRAME_START + 2)) ${GLOBAL_MAIN_FRAME_START_ADDRESS} ${GLOBAL_FRAME_SIZE}
    # NOTE AI: As you can see from tmp/RAM.txt file we do not clear the RAM memory where poped frame was stored while for push_frame we call clear_main_frame function.
    #          What are the Pros & Cons for each approach?
    #          Read about disk zeroing as well. 
}

export -f clear_main_frame
export -f push_frame
export -f pop_frame

