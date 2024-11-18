.data
	buffer:	.space 8
	filename:	.asciiz	"FLOAT2.BIN"
	inf:	.word	0x7F800000
	underflow_msg:	.asciiz	"Underflow detected"
	overflow_msg:	.asciiz	"Overflow detected"
	denormal_msg:	.asciiz	"Operand have denormalized numbers"
	special_msg:	.asciiz "Operand is infinity or NaN"
	operand_1_msg:	.asciiz "Value of (1): "
	operand_2_msg:	.asciiz "Value of (2): "
	result_msg:	.asciiz "Result: "
	newline:	.asciiz "\n"
.text
.globl main
main:
	# Call func to read file
	jal	read_file
	
	# Set arg and call multiply float func
	add	$a0,	$zero,	$v0	# $a0 = first float value (1)
	add	$a1,	$zero,	$v1	# $a1 = second float value (2)
	jal	multiply_float
	
	# Print intput value and result
	add	$t0,	$zero,	$a0	# save (1)
	add	$t1,	$zero,	$a1	# save (2)
	add	$t2,	$zero,	$v0	# save result
	
	la	$a0,	operand_1_msg	# get address of msg to print (1)
	add	$a1,	$zero,	$t0	# get (1)
	jal 	print_float
	
	la	$a0,	operand_2_msg	# get address of msg to print (2)
	add	$a1,	$zero,	$t1	# get (1)
	jal 	print_float
	
	la	$a0,	result_msg	# get address of msg to print result
	add	$a1,	$zero,	$t2	# get result
	jal 	print_float
	
	j	exit

# Usage: Read two float number from file to register
# Input: None
# Input: $v0, $v1 - Two float value
read_file:
	add	$v0,	$zero,	13	# syscall 13: Open file
	la	$a0,	filename	# Address of read file
	add	$a1,	$zero,	0	# Flag: Only-read
	add	$a2,	$zero,	0	# Mode: Ignored
	syscall
	add	$a0,	$zero,	$v0	# Move file descriptor into $a0
	
	add	$v0,	$zero,	14	# syscall 14: read from file
	# 	$a0 already has file descriptor
	la	$a1,	buffer		# Address of input buffer
	addi	$a2,	$zero,	8	# 2 value (8 bytes)
	syscall

	li   	$v0, 	16       	# Syscall 16: close file
    	# 	$a0 already has file descriptor
    	syscall
	
	lw	$v0,	0($a1)		# store first value to return reg.
	lw	$v1,	4($a1)		# store second value to return reg.
	
	
	jr	$ra

# Usage: Multiply two float numbers
# Input: $a0, $a1 - Two float numbers
# Output: $v0 - Return product
multiply_float:
	# Store $ra because we need call many func later
	addi	$sp,	$sp,	-4	# Set space to save reg.
	sw	$ra,	0($sp)		# Store $ra before call func
	
	# Check if input value is zero
	add	$v0,	$zero,	$zero
	sll	$t0,	$a0,	1		# no check sign bit
	beqz	$t0,	end_multiply_func	# if exponent and mantissa of (1) = 0, return 0
	sll	$t0,	$a1,	1		# no check sign bit
	beqz	$t0,	end_multiply_func	# # if exponent and mantissa of (2) = 0, return 0
	
	# Check special case (Inf or NaN)
	jal	check_special_number
	
	# Extract exponents
	addi	$t0,	$zero,	0x7F800000	# 0111 1111 1000 -> get bit[30:23]
	and	$t1,	$a0, 	$t0		
	srl	$t1,	$t1,	23		# Have true exponent of (1)
	and	$t2,	$a1,	$t0
	srl	$t2,	$t2,	23		# Have true exponent of (2)
	
	# Check for denormalized number
	beqz	$t1,	handle_denormal
	beqz	$t2,	handle_denormal
	
	# Calculate final exponent
	add	$t0,	$t1,	$t2		# $t0 = exponent(1) + exponent(2) 
	addi	$t0,	$t0,	-127		# subtract bias because we have two bias added above
	add	$s0,	$zero,	$t0		# $s0 store final exponent
	
	# Extract mantissas with hidden bit
	addi	$t0,	$zero,	0x7FFFFF	# 0000 0000 0111 1111 .... -> get bit [22:0]
	and	$t1,	$a0,	$t0		# get mantissa of (1)
	ori	$t1,	$t1,	0x800000	# Add hidden bit 1
	and	$t2,	$a1,	$t0		# get mantissa of (2)
	ori	$t2,	$t2,	0x800000	# Add hidden bit 1
	
	# Multiply mantissas
	mult	$t1,	$t2
	mfhi	$t1	
	mflo	$t2
	
	# Check if need normalize
	srl	$t0,	$t1,	15		# in case no need normalize, result has 47 bit (14 bit at hi)
	beqz	$t0,	not_normalize

	# Normalize but not really standard normalize
	sll	$t0,	$t1,	31		# move last bit to position 31, temporary call x
	srl	$t1,	$t1,	1		# keep hi has 14 bit as usual
	srl	$t2,	$t2,	1		# to add last bit x of hi to first bit of lo
	or	$t2,	$t2,	$t0		# lo will become xyyyy... where y are bit of lo
	addi	$s0,	$s0,	1		# add final exponent
	
not_normalize:
	# Calculate final mantissa
	sll	$t1,	$t1,	9		# to get 23 bit, because hi has already 14 bit, so we need 9 bit of lo 
	srl 	$t2	$t2,	23		# 9 high bit of lo will in [8:0]
	or	$t1,	$t1,	$t2		# now in $t1 will have 23 bit of mantissa and still have hidden bit 1
	andi	$s1,	$t1,	0x7FFFFF	# remove hidden bit 1 to have final mantissa, final mantissa store in $s1

	# Check underflow
	bltz	$s0,	handle_underflow	# If final exponent (
	
	# Check overflow
	addi	$t0,	$zero,	255
	slt	$t1,	$t0,	$s0		# If final exponent ($s0) > 255, then $t1 = 1	
	bnez	$t1,	handle_overflow		# $t1 = 1 -> throw overflow
	 
	# Calculate sign bit
	srl	$t1,	$a0, 	31		# get sign bit of (1)
	srl	$t2,	$a1,	31		# get sign bit of (2)
	xor	$t0,	$t1,	$t2		# calculate final sign bit, 0 if $t1, $t2 have the same value else 1
	 
	# Combine final result
	sll	$v0,	$t0,	31		# put final sign bit at position 31 of return result
	sll	$s0,	$s0,	23		# put final exponent at [30: 23]
	or	$v0,	$v0,	$s0		# assign final exponent to return result
	or	$v0,	$v0,	$s1		# assign final mantissa to return result

end_multiply_func:
	lw	$ra,	0($sp)			# get $ra of func back
	add	$sp,	$sp,	4		# pop from stack
	jr	$ra

# Usage: Print message and value in float type
# Input: $a0 - address of message need to print, $a1 - value need to print
# Output: None
print_float:
	addi	$v0,	$zero,	4	# Syscall 4: print string
	# $a0 has address of message already
	syscall
	
	mtc1	$a1,	$f12		# $f12: float to print
	addi	$v0,	$zero,	2	# Syscall 2: print float
	syscall
	
	li   	$v0, 	4        	# Syscall 4: print string
    	la   	$a0, 	newline		# print new line
    	syscall
	
	jr	$ra

# Usage: Check if 2 value either infinity or NaN, exit if true
# Input: $a0, $a1 - two float value
# Output: None
check_special_number:
	add	$t0,	$zero,	0x7F800000	# Infinity/NaN pattern
	and	$t1,	$a0,	$t0		# check if (1) is inf/NaN
	beq	$t1,	$t0,	handle_special_number
	and	$t1,	$a1,	$t0		# check if (2) is inf/NaN
	beq	$t1,	$t0,	handle_special_number
	jr	$ra
	
# Usage: Throw in case value is inf or NaN number
# Input: None
# Output: None
handle_special_number:
	la	$a0,	special_msg		# Address of special msg
	addi	$v0,	$zero,	4		# Syscall 4: print string
	syscall 
	j exit
	
# Usage: Throw in case value is denormalized number
# Input: None
# Output: None
handle_denormal:
	la	$a0,	denormal_msg		# Address of special msg
	addi	$v0,	$zero,	4		# Syscall 4: print string
	syscall 
	j exit

# Usage: Throw in case exponent is underflow
# Input: None
# Output: None	
handle_underflow:
	la	$a0,	underflow_msg		# Address of special msg
	addi	$v0,	$zero,	4		# Syscall 4: print string
	syscall 
	j exit
	
# Usage: Throw in case exponent is overflow
# Input: None
# Output: None	
handle_overflow:
	la	$a0,	overflow_msg		# Address of special msg
	addi	$v0,	$zero,	4		# Syscall 4: print string
	syscall 
	j exit

# Exit program
exit:
	add	$v0,	$zero,	10
	syscall	
