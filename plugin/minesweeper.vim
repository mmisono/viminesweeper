"=============================================================================
" Name: minesweeper.vim
" Author: mfumi
" Email: m.fumi760@gmail.com
" Version: 0.0.1

if exists('g:loaded_minesweeper_vim')
	finish
endif
let g:loaded_minesweeper_vim = 1

let s:save_cpo = &cpo
set cpo&vim

" ----------------------------------------------------------------------------

let s:MineSweeper = {
			\ 'board1' : [],
			\ 'board2' : [],
			\ 'width'  : 0,
			\ 'height' : 0,
			\ 'num_of_mine' : 0,
			\ 'num_of_flag' : 0,
			\ 'status'      : 0,
			\ 'mine_is_set' : 0,
			\ 'start_time'  : 0,
			\ 'end_time'    : 0,
			\}

function! s:MineSweeper.run(width,height,num_of_mine)

	if a:width*a:height < (a:num_of_mine+1)
		echoerr "number of mine is too big"
		return
	endif

	let winnum = bufwinnr(bufnr('==MineSweeper=='))
	if winnum != -1
		if winnum != bufwinnr('%')
			exe "normal \<c-w>".winnum."w"
		endif
	else
		exec 'silent split ==MineSweeper=='
	endif

	let self.width = a:width
	let self.height = a:height
	let self.num_of_mine = a:num_of_mine
	call self.initialize_board()
	call self.draw()

	if has("conceal")
		syn match MineSweeperStatusBar contained "|" conceal
	else
		syn match MineSweeperStatusBar contained "|"
	endif
	syn match MineSweeperStatus '.*' contains=MineSweeperStatusBar
	syn match MineSweeperBomb   '\*'
	syn match MineSweeperField  '\.'
	syn match MineSweeperFlag   'F'
	syn match MineSweeperHatena '?'
	syn match MineSweeper0      '0'
	syn match MineSweeper1      '1'
	syn match MineSweeper2      '2'
	syn match MineSweeper3      '3'
	syn match MineSweeper4      '4'
	syn match MineSweeper5      '5'
	syn match MineSweeper6      '6'
	syn match MineSweeper7      '7'
	syn match MineSweeper8      '8'
	hi MineSweeperStatus ctermfg=darkyellow  guifg=darkyellow
	hi MineSweeperBomb   ctermfg=brown       ctermbg=gray guifg=brown       guibg=gray
	hi MineSweeperField  ctermfg=gray        ctermbg=gray guifg=gray        guibg=gray  
	hi MineSweeperFlag   ctermfg=darkmagenta ctermbg=gray guifg=darkmagenta guibg=gray
	hi MineSweeperHatena ctermfg=darkblue    ctermbg=gray guifg=darkblue    guibg=gray
	hi MineSweeper0      ctermfg=darkgray    ctermbg=gray guifg=darkgray    guibg=gray  
	hi MineSweeper1      ctermfg=blue        ctermbg=gray guifg=blue        guibg=gray  
	hi MineSweeper2      ctermfg=green       ctermbg=gray guifg=green       guibg=gray  
	hi MineSweeper3      ctermfg=red         ctermbg=gray guifg=red         guibg=gray  
	hi MineSweeper4      ctermfg=darkred     ctermbg=gray guifg=darkred     guibg=gray  
	hi MineSweeper5      ctermfg=red         ctermbg=gray guifg=red         guibg=gray  
	hi MineSweeper6      ctermfg=red         ctermbg=gray guifg=red         guibg=gray  
	hi MineSweeper7      ctermfg=red         ctermbg=gray guifg=red         guibg=gray  
	hi MineSweeper8      ctermfg=red         ctermbg=gray guifg=red         guibg=gray  

	nnoremap <silent> <buffer> x  			:call <SID>_click()<CR>
	nnoremap <silent> <buffer> <LeftMouse>  :call <SID>_click()<CR>
	nnoremap <silent> <buffer> v  			:call <SID>_right_click()<CR>
	nnoremap <silent> <buffer> <RightMouse> :call <SID>_right_click()<CR>
	nnoremap <silent> <buffer> zz 			:call <SID>_wheel_click()<CR>
	
	augroup MineSweeper
		autocmd!
		autocmd  CursorMoved \*MineSweeper\* call <SID>_set_caption()
	augroup END
	
	setl conceallevel=2
	setl nonumber
	setl noswapfile
	setl nomodified
	setl nomodifiable
	setl bufhidden=delete
endfunction


function! s:MineSweeper.click()
	let pos = getpos('.')
	let x = pos[2]-1
	let y = pos[1]-2
	if y < 0 | return | endif
	if !self.mine_is_set
		let self.mine_is_set = 1
		call self.set_mine(x,y)
		let self.start_time = reltime()
	endif

	if self.board2[y][x] == 'F' ||
				\ self.board2[y][x] == '?' 
		return
	elseif self.board1[y][x] == '*'
		let self.board2 = copy(self.board1)
		let self.status = 1
		let self.end_time = reltime()
		" call s:message("Bomb!!!")
	else
		try
			call self.expand(x,y)
		catch /E132/
		endtry
		if self.check_board()
			let self.status = 2
			let self.end_time = reltime()
			" call s:message("Clear!")
		endif
	endif
	call self.draw()
	call setpos('.',pos)
endfunction

function! s:MineSweeper.right_click()
	let pos = getpos('.')
	let x = pos[2]-1
	let y = pos[1]-2
	if y < 0 | return | endif
	let c = ['.','F','?']
	if self.board2[y][x] == '.'
		let self.num_of_flag += 1
	elseif self.board2[y][x] == 'F'
		let self.num_of_flag -= 1
	endif
	let idx = index(c,self.board2[y][x])
	if idx != -1 
		let self.board2[y][x] = c[(idx+1)%3]
	endif
	call self.draw()
	call setpos('.',pos)
endfunction

function! s:MineSweeper.wheel_click()
	let pos = getpos('.')
	let x = pos[2]-1
	let y = pos[1]-2
	if y < 0 | return | endif
	if self.board2[y][x] == '.' ||
	\  self.board2[y][x] == 'F' ||
	\  self.board2[y][x] == '?' 
		return
	endif

	let cnt = 0
	for i in range(-1,1)
		for j in range(-1,1)
			if self.check_coord(x+j,y+i)
				if self.board2[y+i][x+j] == 'F'
					let cnt += 1
				endif
			endif 
		endfor
	endfor
	
	if cnt != self.board1[y][x]
		return
	endif
	
	for i in range(-1,1)
		for j in range(-1,1)
			try
				if self.check_coord(x+j,y+i) &&
				\  self.board2[y+i][x+j] != 'F'
			 		if self.board1[y+i][x+j] == '*'
						let self.board2 = copy(self.board1)
						let self.status = 1
						let self.end_time = reltime()
						break
					endif
					call self.expand(x+j,y+i)
				endif
			catch /E132/
			endtry
		endfor
		if self.status == 1 | break | endif
	endfor

	if self.check_board()
		let self.status = 2
		let self.end_time = reltime()
	endif
	
	call self.draw()
	call setpos('.',pos)
endfunction

function! s:MineSweeper.check_coord(x,y)
	return  a:x >= 0 && a:y >= 0 && a:x < self.width && a:y < self.height
endfunction

function! s:MineSweeper.check_board()
	let cnt = 0
	for i in range(self.height)
		for j in range(self.width)
			if  self.board2[i][j] != 'F' &&
						\ self.board2[i][j] != '.'
				let cnt += 1
			endif
		endfor
	endfor
	return (self.width * self.height - cnt) == self.num_of_mine
endfunction

function! s:MineSweeper.expand(x,y)
	let self.board2[a:y][a:x] = self.board1[a:y][a:x]
	if self.board1[a:y][a:x] != '0'
		return
	endif
	for i in range(-1,1)
		for j in range(-1,1)
			if (i != 0 || j != 0) &&
						\ self.check_coord(a:x+j,a:y+i) && 
						\ self.board1[a:y+i][a:x+j] != 'x' &&
						\ self.board2[a:y+i][a:x+j] == '.'
				call s:MineSweeper.expand(a:x+j,a:y+i)
			endif
		endfor
	endfor
endfunction

function! s:MineSweeper.initialize_board()
	let self.start_time =  0
	let self.end_time   =  0
	let self.mine_is_set = 0
	let self.num_of_flag = 0
	let self.status = 0
	let self.board1 = []
	let self.board2 = []
	for i in range(self.height)
		call add(self.board1,[])
		call add(self.board2,[])
		for j in range(self.width)
			call add(self.board1[i],'0')
			call add(self.board2[i],'.')
		endfor
	endfor
endfunction

function! s:MineSweeper.set_mine(cur_x,cur_y)
	let i = 0
	while i < self.num_of_mine
		let x = s:rand() % self.width
		let y = s:rand() % self.height
		if (x != a:cur_x || y != a:cur_y) && 
					\ self.board1[y][x] == '0' 
			let self.board1[y][x] = '*'
			let i+= 1
		endif
	endwhile

	for i in range(self.height)
		for j  in range(self.width)

			if self.board1[i][j] != '*' 
				let cnt = 0
				for k in range(-1,1)
					for l in range(-1,1)
						if (k != 0 || l != 0) && 
									\ self.check_coord(j+l,i+k)
							if self.board1[i+k][j+l] == '*'
								let cnt += 1
							endif
						endif
					endfor 
				endfor
				let self.board1[i][j] = string(cnt)
			endif

		endfor
	endfor
endfunction

function! s:MineSweeper.set_caption()
	setl modifiable

	let status = ['',"Bomb!!!","Clear!"]
	if type(self.start_time) == type([])
		if type(self.end_time) == type([])
			let _time = reltimestr(reltime(self.start_time,self.end_time))
		else
			let _time = reltimestr(reltime(self.start_time))
		endif
		let match_end = matchend(_time, '\d\+\.') - 2
		let time = _time[:match_end]
	else
		let time = 0 
	endif
	let str = printf("| %3s - %2d/%2d %s |", 
				\ time,self.num_of_flag,
				\ self.num_of_mine,status[self.status])
	call setline(1,str)
	
	setl nomodified
	setl nomodifiable
endfunction

function! s:MineSweeper.draw()
	setl modifiable
	silent %d _

	call self.set_caption()

	setl modifiable
	for i in range(self.height)
		let str = join(self.board2[i],'')
		call append(line('$'),str)
	endfor

	setl nomodified
	setl nomodifiable
endfunction

let s:rand_num = 1
function! s:rand()
	if has('reltime')
		let match_end = matchend(reltimestr(reltime()), '\d\+\.') + 1
		return reltimestr(reltime())[l:match_end : ]
	else
		" awful
		let s:rand_num += 1
		return s:rand_num
	endif
endfunction

function! s:message(msg)
	echohl WarningMsg
	echo a:msg
	echohl None
endfunction

function! s:_minesweeper(...)
	if a:0 == 0
		call s:MineSweeper.run(9,9,10)
	elseif a:1 == 'easy'
		call s:MineSweeper.run(9,9,10)
	elseif a:1 == 'normal'
		call s:MineSweeper.run(16,16,40)
	elseif a:1 == 'hard'
		call s:MineSweeper.run(30,16,99)
	elseif a:1 == 'custom'
		if a:0 >= 4
			call s:MineSweeper.run(a:2,a:3,a:4)
		else
			call s:message("usage: MineSweeper [easy,normal,hard]")
			call s:message("       MineSweeper  custom {width} {height} {num_of_mine}")
		endif
	else
		call s:message("usage: MineSweeper [easy,normal,hard]")
		call s:message("       MineSweeper  custom {width} {height} {num_of_mine}")
	endif
endfunction

function! s:_click()
	call call(s:MineSweeper.click,[],s:MineSweeper)
endfunction

function! s:_right_click()
	call call(s:MineSweeper.right_click,[],s:MineSweeper)
endfunction

function! s:_wheel_click()
	call call(s:MineSweeper.wheel_click,[],s:MineSweeper)
endfunction

function! s:_set_caption()
	call call(s:MineSweeper.set_caption,[],s:MineSweeper)
endfunction

function! s:level(ArgLead,CmdLine,CursorPos)
	return ["easy","normal","hard","custom"]
endfunction

command! -nargs=* -complete=customlist,s:level 
			\ MineSweeper call s:_minesweeper(<f-args>)

" ----------------------------------------------------------------------------

let &cpo = s:save_cpo
unlet s:save_cpo

