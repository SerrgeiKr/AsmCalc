include includes\win64.inc
include includes\user32.inc
includelib includes\user32.lib
include includes\kernel32.inc
includelib includes\kernel32.lib
include includes\msvcrt.inc
includelib includes\msvcrt.lib
;al contains current character
;ah contains previous character (usually)
;rdx points to the current character
;rbx works like a boolean stack for multiply actions
;r9 contains return address
;r8 contains boolean vars
.data
format	db		'%f', 0dh, 0ah, 0 	;Format output string
zero	db 		0					;It's not a variable, it's just a zero, it MUST be here!
buf 	db 		128 dup(?)			;Input string buffer
input 	dq 		?					;Input handle
output 	dq 		?					;Output handle
chread 	dq 		?					;Number of characters read
num 	dq 		?					;Just a variable
.code
Main proc 
	;Get hanles
    mov rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov input, rax
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov output, rax
minput:
	;Input
    mov rcx, input
    mov rdx, offset buf
    mov r8, 127
    mov r9, offset chread
    push 0
    call ReadConsole
;Set pointer to the end of string
    xor rdx, rdx
    mov rdx, offset zero
    add rdx, chread
    dec rdx
    dec rdx
    ;Do magic!
    call Calc
    ;Print result
    mov rcx, offset format
    mov rdx, rax
    call printf
    ;Repeat
    jmp minput
Main endp

Calc proc
	;Initialization
	mov rbp, rsp
	xor rax, rax
	xor r8, r8
	;Push 3 zeroes to be safe
	push 0
	push 0
	push 0
cstart:
	mov ah, al			;Store previous character in ah
	mov al, [rdx]		;Get current character
	;It's a switch for al
	cmp al, '0'
	jl mnext1
	cmp al, '9'
	jle mnum
	
mnext1:
	cmp al, ')'			
	je mclbr
	
	cmp al, '+'
	je madd
	cmp al, '('
	je mobr
	test al, al
	jz madd
	
	cmp al, 'a'
	jl mnext2
	cmp al, 'z'
	jle mfunc
	
mnext2:
	cmp al, ','
	je mcomma
	
	cmp al, '-'
	je mneg
	
	cmp al, '*'
	je mmul
	
	cmp al, '/'
	je mdiv
	;If the character is unknowm just ignore it
	dec rdx
	jmp mend
	
	;If the character is a number
mnum:
	finit
	xor ecx, ecx
	mov byte ptr [num], 10
	fild word ptr [num]			;Put 10 in fpu
	fldz						;Put aggregator value
nstart:
	sub al, '0'					;Char to int
	mov byte ptr [num], al		;Store al in num
	fild word ptr [num]			;Convert the number to double and put in the fpu
	
	fadd						;Add new number to the aggregator
	fdiv st, st(1)				;Divide by 10
	
	inc ecx						;Increment digit counter
	dec rdx						;Set the pointer to the next character
	
	mov al, [rdx]				;Get the next character
	cmp al, '.'					;If char is '.' reset digit counter
	jne nnext1
	xor ecx, ecx
	dec rdx						;Go to the next character
	mov al, [rdx]
nnext1:
	cmp al, '0'					;If the character is number go to next iteration
	jl nend
	cmp al, '9'
	jle nstart
	
nend:
	fmul st, st(1)				;Multiply by 10
	dec ecx
	jnz nend
								;Put the number into the stack
	sub rsp, 8
	fstp qword ptr[rsp]
	jmp mend					
	
mmul1:
	bt bx, 0					;Check if multiplication is needed
	jnc mendmul					
	finit
	fld qword ptr[rsp]
	add rsp, 8
	fmul qword ptr[rsp]
	fstp qword ptr[rsp]
	btr rbx, 0					;Reset multiplicaton bit
mendmul:
	jmp r9						;Return
	
mclbr:
	shl rbx, 1					;Push false into multiply stack
	push 0						;Push 0 to prevent next number from adding to previous one
	dec rdx
	jmp mend
	
mcomma:
	bts r8, 1					;Comma works like )(
	
mobr:
	bts r8, 0					;( should perform after adding
	cmp ah, '-'					;if previous character was '-' don't add
	je maddobr
madd:
	mov r9, madd1				;Put return address in r9 and multiply
	jmp mmul1
madd1:
	fld qword ptr[rsp]
	add rsp, 8
	fadd qword ptr[rsp]
	fstp qword ptr[rsp]
	
maddobr:
	dec rdx
	btr r8, 0					;Do '(' action if needed
	jnc maddend
	shr rbx, 1				
maddend:
	btr r8, 1					;Do ')' action if needed
	jnc mend
	shl rbx, 1					;Pop multiply stack
	push 0
	jmp mend
	
mfunc:
	xor ah, ah
mfunc1:
	;Read function name into rax
	shl rax, 8
	dec rdx 
	mov al, [rdx]
	cmp al, 'a'
	jl fcmp
	cmp al, 'z'
	jle mfunc1
fcmp:
	cmp eax, 'ip'	;pi
	je mpi
	shr rax, 8
	finit
	fld qword ptr [rsp]			;Load first argument
	cmp eax, 'trqs'	;sqrt
	je msqrt
	cmp eax, 'nis'	;sin
	je msin
	cmp eax, 'soc'	;cos
	je mcos
	cmp eax, 'nat'	;tan
	je mtan
	cmp eax, 'nata'	;atan
	je matan
	cmp eax, 'wop'	;pow
	je mpow
mpi:
	fldpi
	jmp mfret
msqrt:
	fsqrt
	jmp mfret
msin:
	fsin
	jmp mfret
mcos:
	fcos
	jmp mfret
mtan:
	fptan
	fxch
	jmp mfret
matan:
	fld1
	fpatan
	jmp mfret
mpow:
	fld1						;Load aggregator
	add rsp, 8					;Convert second argument to int and load it into the counter
	fld qword ptr [rsp]
	fistp qword ptr [rsp]
	mov ecx, [rsp]
mpowmul:
	;Calculate
	dec ecx
	fmul st, st(1)
	test ecx, ecx
	jnz mpowmul
mfret:
	;Reset rax and save al
	mov cl, al
	xor eax, eax				;It works like xor rax, rax but it's shorter
	mov al, cl
	fst qword ptr [rsp]			;Save result
	mov r9, mend				;Multiply if needed
	jmp mmul1
	
mneg:
	btc qword ptr [rsp], 63		;Make the number negative
	jmp madd					;Then just add
mdiv:
	;Divide 1 by current number and save it and then multiply
	finit
	fld1 
	fdiv qword ptr [rsp]
	fst qword ptr [rsp]
mmul:
	mov r9, mmuln
	jmp mmul1
mmuln:
	btc rbx, 0					;Set multiply bit
	dec rdx
mend:
	test al, al					;If character is not zero go to next iteration
	jnz cstart
mret1:
	;Do last addition and return value
	fld qword ptr[rsp]
	add rsp, 8
	fadd qword ptr[rsp]
	fst qword ptr[rsp]
	pop rax
	mov rsp, rbp
	ret
Calc endp

end