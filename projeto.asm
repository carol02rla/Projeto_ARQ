.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\masm32.lib

include \masm32\include\msvcrt.inc
includelib \masm32\lib\msvcrt.lib
include \masm32\macros\macros.asm

.data
requestFile db "Digite o nome do arquivo a ser lido:", 0H
requestOutFile db "Digite o nome do arquivo de saida:", 0H
requestX db "Digite o valor da coordenada x:", 0H
requestY db "Digite o valor da coordenada y:", 0H
requestW db "Digite a largura da censura:", 0H
requestH db "Digite a altura da censura:", 0H

fileName db 50 dup(0)    ; input com o nome do arquivo de entrada
outFileName db 50 dup(0) ; input com o nome do arquivo de saida
fileBuffer db 54 dup(0)  ; inicializacao do array que vai armazenar os bytes do cabecalho da imagem
linhaImg db 6480 dup(0)  ; inicializacao do array que vai armazenar os pixels da linha da imagem
inputVar db 20 dup(0)    ; input com variaveis que serao convertidas para dword

contLinhas dd 0 ; variavel para armazenar a quantidade de linhas percorridas da imagem
larguraImg dd 0 ; variavel para armazenar a largura da imagem
pos_x dd 0      ; coordenada x do pixel a partir do qual a imagem deve ser censurada
pos_y dd 0      ; coordenada y do pixel a partir do qual a imagem deve ser censurada
w_ret dd 0      ; largura do retangulo de censura
h_ret dd 0      ; altura do retangulo de censura

fileHandle dd 0    ; variavel para armazenar o handle do arquivo de entrada
outFileHandle dd 0 ; variavel para armazenar o handle do arquivo de saida
inputHandle dd 0   ; variavel para armazenar o handle de entrada
outputHandle dd 0  ; variavel para armazenar o handle de saida

consoleCount dd 0 ; variavel para armazenar caracteres lidos/escritos na console
readCount dd 0    ; variavel para armazenar a quantidade de bytes lidos no arquivo
writeCount dd 0   ; variavel para armazenar a quantidade de bytes escritos no arquivo

.code

tratamentoString: ; funcao para remover CR e LF de uma string
    push ebp
    mov ebp, esp
    sub esp, 4

    mov eax, DWORD PTR[ebp+8]
    mov DWORD PTR [ebp-4], eax
    mov esi, DWORD PTR [ebp-4] ; Armazenar apontador da string em esi
  proximo:
    mov al, [esi] ; Mover caractere atual para al
    inc esi ; Apontar para o proximo caractere
    cmp al, 13 ; Verificar se eh o caractere ASCII CR - FINALIZAR
    jne proximo
    dec esi ; Apontar para caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    mov esp, ebp
    pop ebp
    ret 4

convertePixel: ; funcao para converter uma coordenada da imagem para pixels
    push ebp
    mov ebp, esp
    sub esp, 4

    mov eax, DWORD PTR[ebp+8]
    mov DWORD PTR [ebp-4], eax
    mov ebx, 3
    mul ebx ; EAX = EAX*EBX

    mov esp, ebp
    pop ebp
    ret 4

calculaLargura: ; funcao para calcular largura da imagem
    push ebp
    mov ebp, esp
    sub esp, 4

    mov edx, DWORD PTR[ebp+8]
    mov DWORD PTR [ebp-4], edx
    mov al, BYTE PTR[edx + 0]
    mov ah, BYTE PTR[edx + 1]

    mov ebx, 3
    mul ebx

    mov esp, ebp
    pop ebp
    ret 4

funcaoCensura: ; funcao para censurar pixels de uma linha
    push ebp
    mov ebp, esp
    sub esp, 12

    mov eax, DWORD PTR[ebp + 16]
    mov ebx, DWORD PTR[ebp + 12]
    mov edx, DWORD PTR[ebp + 8]

    mov DWORD PTR[ebp - 4], edx
    mov DWORD PTR[ebp - 8], ebx
    mov DWORD PTR[ebp - 12], eax

    mov ecx, ebx
    add edx, ebx ; armazena em edx o limite do pixel a ser pintado (pos_x+w_ret)
    
  pintar_pixel:
    mov BYTE PTR[eax + ecx + 0], 0
    mov BYTE PTR[eax + ecx + 1], 0
    mov BYTE PTR[eax + ecx + 2], 0

    add ecx, 3
    cmp ecx, edx
    jl pintar_pixel ; se pos_x <= pixel < pos_x+w_ret, o pixel eh censurado

    mov esp, ebp
    pop ebp
    ret 12


start:
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov inputHandle, eax
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov outputHandle, eax

    ; input do nome dos arquivos
    invoke WriteConsole, outputHandle, addr requestFile, sizeof requestFile, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr fileName, sizeof fileName, addr consoleCount, NULL

    invoke WriteConsole, outputHandle, addr requestOutFile, sizeof requestOutFile, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr outFileName, sizeof outFileName, addr consoleCount, NULL

    push offset fileName
    call tratamentoString ; tratamento da string com o nome do arquivo de entrada

    push offset outFileName
    call tratamentoString ; tratamento da string com o nome do arquivo de saida

    ; input das variaveis de entrada
    invoke WriteConsole, outputHandle, addr requestX, sizeof requestX, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputVar, sizeof inputVar, addr consoleCount, NULL

    push offset inputVar
    call tratamentoString ; tratamento da string com a variavel
    invoke atodw, addr inputVar ; conversao para dword
    mov pos_x, eax
    push pos_x
    call convertePixel ; converte x para pixels para posicionamento do retangulo de censura
    mov pos_x, eax

    invoke WriteConsole, outputHandle, addr requestY, sizeof requestY, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputVar, sizeof inputVar, addr consoleCount, NULL

    push offset inputVar
    call tratamentoString
    invoke atodw, addr inputVar
    mov pos_y, eax

    invoke WriteConsole, outputHandle, addr requestW, sizeof requestW, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputVar, sizeof inputVar, addr consoleCount, NULL

    push offset inputVar
    call tratamentoString
    invoke atodw, addr inputVar
    mov w_ret, eax
    push w_ret
    call convertePixel ; converte w para pixels para dimensionar a largura do retangulo de censura
    mov w_ret, eax

    invoke WriteConsole, outputHandle, addr requestH, sizeof requestH, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputVar, sizeof inputVar, addr consoleCount, NULL

    push offset inputVar
    call tratamentoString
    invoke atodw, addr inputVar
    mov h_ret, eax

    ; manipulacao de arquivos (abertura-leitura-escrita)
    invoke CreateFile, addr fileName, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov fileHandle, eax

    invoke ReadFile, fileHandle, addr fileBuffer, 18, addr readCount, NULL

    invoke CreateFile, addr outFileName, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov outFileHandle, eax

    invoke WriteFile, outFileHandle, addr fileBuffer, 18, addr writeCount, NULL

    invoke ReadFile, fileHandle, addr fileBuffer, 4, addr readCount, NULL
    
    push offset fileBuffer
    call calculaLargura
    mov larguraImg, eax

    invoke WriteFile, outFileHandle, addr fileBuffer, 4, addr writeCount, NULL

    invoke ReadFile, fileHandle, addr fileBuffer, 32, addr readCount, NULL
    invoke WriteFile, outFileHandle, addr fileBuffer, 32, addr writeCount, NULL

  loop_leitura_escrita: ; loop para percorrer todas as linhas da imagem

    invoke ReadFile, fileHandle, addr linhaImg, larguraImg, addr readCount, NULL

    cmp readCount, 0 ; se readCount = 0, o arquivo chegou ao fim
    je fim_leitura_escrita

    add contLinhas, 1
    mov ebx, pos_y

    cmp contLinhas, ebx
    jl copia_linha
    add ebx, h_ret ; ebx armazena o limite da linha ate onde deve ser feita a censura (pos_y+h_ret)
    cmp contLinhas, ebx
    jge copia_linha

    ; se pos_y <= contLinhas < pos_y+h_ret, entao eh feita a censura nas linhas
    push offset linhaImg
    push pos_x
    push w_ret
    call funcaoCensura

  copia_linha:

    ; para as demais linhas, eh feita uma copia da linha da imagem de entrada
    invoke WriteFile, outFileHandle, addr linhaImg, larguraImg, addr writeCount, NULL

    jmp loop_leitura_escrita

  fim_leitura_escrita:

    ; fechamento dos arquivos
    invoke CloseHandle, fileHandle
    invoke CloseHandle, outFileHandle

    invoke ExitProcess, 0
end start
