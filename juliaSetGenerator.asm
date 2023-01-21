.eqv 	BMP_FILE_SIZE	786486		# 512 * 512 * 3 + 54
.eqv 	BYTES_PER_ROW	1536		# 512 * 1 * 3
.eqv 	BLACK 		0x000000	    # colors
.eqv 	LIGHTEST 	0xFFCAE9
.eqv 	LIGHTER 	0xFFB0E0
.eqv 	LIGHT 		0xFF72BE
.eqv 	MEDIUM 		0xFF36B6
.eqv 	DARK 		0xD82A98
.eqv 	DARKER 		0xAF0C63
.eqv 	DARKEST 	0x52022D

	.data
.align 4
res:	.space 2
image:	.space BMP_FILE_SIZE
cx:	.word 0
cy:	.word 0

prompt_cx:	.asciiz "Program generates and saves Julia set to file julia.bmp\nGive the real part of the complex parameter (Q8.24): "
prompt_cy:	.asciiz "Give the imaginary part of the complex parameter (Q8.24): "
f_name:  	.asciiz "julia.bmp"

#------------- selected numbers in the Q8.24 format--------------
# 0.125 - 2097152
# 0.25 - 4194304
# 0.5 - 8388608
# 0.75 - 12582912

	.text	
#-----------Print information about program and take parameters from a user----------
	la $a0, prompt_cx 		#print prompt_cx
	li $v0, 4
	syscall
	
	li $v0, 5			#read Re(c)
	syscall	
	sw $v0, cx
	
	
	la $a0, prompt_cy		#print prompt_cy
	li $v0, 4
	syscall
	
	li $v0, 5			#read Im(c)
	syscall	
	sw $v0, cy


#----------Header preparation-----------
header_prep:
	la $a0, image
	li $s5, 0x4D42			# sygnature 'BM'
	sh $s5, ($a0)
	li $s5, BMP_FILE_SIZE		# file size
	sw $s5, 2($a0)
	sw $zero, 6($a0)		# reserved, has to be zero
	li $s5, 54			# offset (header size)
	sw $s5, 10($a0)
	li $s5, 40			# size of the header with information
	sw $s5, 14($a0) 
	li $s5, 512			# width and height of the image
	sw $s5, 18($a0)
	sw $s5, 22($a0)
	li $s5, 1			# number of panels
	sh $s5, 26($a0)			# number of panels
	li $s5, 24			# number of bits per pixel
	sh $s5, 28($a0) 
	sw $zero, 30($a0)		# compression type
	sw $zero, 34($a0)		# size after compression
	sw $zero, 38($a0)
	sw $zero, 42($a0)
	sw $zero, 46($a0)		# can have zero value
	sw $zero, 50($a0)		# can have zero value

#----------Calculating Julia set-----------		
julia_set:
	li $s5, 4
	sll $s5, $s5, 24
	div $s4, $s5, 512		# $s4 -> scale
	
	li $s6, -256			# $s6 -> initial pix_x (image center (0,0))
	li $s7, -256			# $s7 -> initial pix_y
	
	lw $t2, cx			# $t2 -> cx value (Re(c))
	lw $t3, cy			# $t3 -> cy value (Im(c))
	li $t4, 4			# $t4 -> r**2
	sll $t4, $t4, 24
	
loop_pixels:
	beq $s6, 256, write_to_file	# if x is equal to maximum value, write to file
	beq $s7, 256, next_x		# if y is equal to maximum value, go to next line
	
	mul $t0, $s6, $s4		# x = pix_x * scale
	mul $t1, $s7, $s4		# y = pix_y * scale
	
	li $t5, 32			# $t5 -> maximum number of iterations

loop_iteration:	
	beqz $t5, color

	mul $t6, $t0, $t0 		# x * x
	mfhi $s5
	srl $t6, $t6, 24
	sll $s5, $s5, 8
	or $t6, $t6, $s5
	
	mul $t7, $t1, $t1 		# y * y
	mfhi $s5
	sll $s5, $s5, 8
	srl $t7, $t7, 24
	or $t7, $t7, $s5
	
	add $t8, $t6, $t7 		# x * x + y * y

	bgt $t8, $t4, color 		# if (x * x + y * y > r**2) go to next y and color pixel
	sub $t9, $t6, $t7		# xtemp = x * x - y * y
	mul $t1, $t1, $t0 		# y = y * x
	mfhi $s5
	sll $s5, $s5, 8
	srl $t1, $t1, 24
	or $t1, $t1, $s5
	sll $t1, $t1, 1 		# y = 2 * y * x
	add $t1, $t1, $t3 		# y = 2 * y * x + cy
	add $t0, $t9, $t2 		# x = xtemp + cx
	
	addi $t5, $t5, -1
	j loop_iteration

color:
	move $a0, $s6 			# $a0 = $s6 -> x
	move $a1, $s7 			# $a1 = $s7 -> y
	add $a0, $a0, 256 		# (0, 0) center of the image -> (0, 0) bottom left corner of the image
	add $a1, $a1, 256

	
	la $s1, image + 10
	lw $s2, ($s1)
	la $s1, image
	add $s2, $s1, $s2 		# $s2 -> address of pixel table
	
	mul $s1, $a1, BYTES_PER_ROW 	# $s1 = y * BYTES_PER_ROW
	mfhi $s5
	or $s1, $s1, $s5
	move $s3, $a0 			# $s3 = 3 * x
	sll $a0, $a0, 1
	add $s3, $s3, $a0
	add $s1, $s1, $s3 		# $s1 = BYTES_PER_ROW + 3 * x
	add $s2, $s2, $s1 		# $s2 = table address + (BYTES_PER_ROW + 3 * x) -> pixel address
	
	
	bgt $t5, 24, greater24
	bgt $t5, 20, greater20
	bgt $t5, 16, greater16
	bgt $t5, 8, greater8
	bgt $t5, 4, greater4
	bgt $t5, 2, greater2
	bgt $t5, 1, greater1	

equal0:
	li $a2, 0
	sb $a2,($s2)		
	srl $a2,$a2,8
	sb $a2,1($s2)		
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y

greater24:
	li $a2, LIGHTEST
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y
	
greater20:
	li $a2, LIGHER
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y

greater16:
	li $a2, LIGHT
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y

greater8:
	li $a2, MEDIUM
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y

greater4:
	li $a2, DARK
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y

greater2:
	li $a2, DARKER
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
	j next_y
	
greater1:
	li $a2, DARKEST
	sb $a2,($s2)
	srl $a2,$a2,8
	sb $a2,1($s2)
	srl $a2,$a2,8
	sb $a2,2($s2)
		
next_y:
	add $s7, $s7, 1		# pix_y++
	j loop_pixels
		
next_x: 
	add $s6, $s6, 1		# pix_x++
	li $s7, -256 		# set pix_y to initial value
	j loop_pixels				
	
#-----------Write to a file-----------
write_to_file:
#open a file
	li  $v0, 13
        la  $a0, f_name
        li  $a1, 1  		# set flag to writing to file
        li $a2, 0  		# ignore mode
        syscall
        
        add $s1, $v0, $zero

#write to a file
	li $v0, 15
	move $a0, $s1
	la $a1, image
	li $a2, BMP_FILE_SIZE
	syscall

#close a file	
	li   $v0, 16   
	move $a0, $s1     
	syscall

		
end: 
	li $v0, 10
	syscall




