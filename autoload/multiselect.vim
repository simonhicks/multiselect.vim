if exists("g:done_multiselect_autoload")
  finish
endif
let g:done_multiselect_autoload = 1

function! s:makevaluemap(values)
  let l:value_map = {}
  for l:value in a:values
    let l:value_map[l:value] = 0
  endfor
  return l:value_map
endfunction

" create a new state object and associate it with the buffer. Most of the rest
" of this script assumes this has been called in the current buffer.
function! s:newstate(values, config)
  let l:value_map = s:makevaluemap(a:values)
  let b:multiselect_state = {
        \ 'values': l:value_map,
        \ 'config': a:config
        \ }
endfunction

" get the multiselect name from the buffer state
function! s:getname()
  return b:multiselect_state['config']['name']
endfunction

" get the last saved set of multiselect values from the buffer state
function! s:getvalues()
  return keys(b:multiselect_state['values'])
endfunction

function! s:getitemstatus(value)
  return b:multiselect_state['values'][a:value]
endfunction

" set the last saved set of multiselect values to a new set of values in the buffer state
function! s:setvalues(value_map)
  let b:multiselect_state['values'] = a:value_map
endfunction

function! s:iskeepchecked()
  if has_key(b:multiselect_state['config'], 'keepchecked')
    return b:multiselect_state['config']['keepchecked']
  else
    return 0
  endif
endfunction

function! s:hascallback(event)
  return has_key(b:multiselect_state['config'], 'on'.a:event)
endfunction

" get the callback function for a particular event type. Options are
" 'checked', 'newchecked', 'unchecked', 'newunchecked'
function! s:getcallback(event)
  return function(b:multiselect_state['config']['on'.a:event])
endfunction

function! s:getaugroupname()
  return "multiselect-".s:getname()
endfunction

" set up the initial state of the buffer
function! s:bufopts(values, config)
  setlocal filetype=todo
  setlocal nobuflisted
  setlocal noswapfile
  call s:newstate(a:values, a:config)
  eval "augroup ".s:getaugroupname()
    au!
    au BufWriteCmd <buffer> call multiselect#write()
  augroup END
endfunction

" purge the buffer and associated augroup
function! s:purge()
  execute "bw! ".s:getname()
  eval "au! ".s:getaugroupname()
endfunction

" create and open a new multiselect buffer
function! s:createnew(values, config)
  execute "new ".a:config['name']
  call s:bufopts(a:values, a:config)
  call s:render()
endfunction

" Turn a string to a item line with the same content
function! s:rendervalueasline(value)
  let l:status = ' '
  if s:getitemstatus(a:value) == 1
    let l:status = 'X'
  end
  return '['.l:status.'] '.a:value
endfunction

" render the buffer stored values as an array of checklist items
function! s:rendervaluesaslines()
  let l:lines = []
  for l:value in s:getvalues()
    call add(l:lines, s:rendervalueasline(l:value))
  endfor
  return l:lines
endfunction

" render the current values in stored buffer state as the text for the buffer
function! s:render()
  normal! ggVGd
  call append(0, s:rendervaluesaslines())
  normal! zRGVdgg
  setlocal nomodified
endfunction

" Extract the original string from an item
function! s:parseitem(line)
  let md = matchlist(a:line, '\[\([X ]\)\] \(.*\)')[1:2]
  let item = {'status': md[0] == 'X', 'text': md[1]}
  return item
endfunction

" return the text content of the buffer as a map of parsed items
function! s:parsebuffer()
  let lnum = 1
  let items = {}
  while lnum <= line("$")
    let l = getline(lnum)
    let v = s:parseitem(l)
    if strlen(l) > 0
      let items[v['text']] = v['status']
    endif
    let lnum = lnum + 1
  endwhile
  return items
endfunction

" return a map containing a list of all checked and all newly checked items
function! s:getchecked()
  let l:checked = {'all':[], 'new':[]}
  let l:old_values = s:getvalues()
  let l:new_state = s:parsebuffer()
  for l:key in keys(l:new_state)
    if l:new_state[l:key]
      call add(l:checked['all'], l:key)
      if !s:getitemstatus(l:key)
        call add(l:checked['new'], l:key)
      endif
    endif
  endfor
  return l:checked
endfunction

" return a map containing a list of all checked and all newly checked items
function! s:getunchecked()
  let l:unchecked = {'all':[], 'new':[]}
  let l:old_values = s:getvalues()
  let l:new_state = s:parsebuffer()
  for l:key in keys(l:new_state)
    if !l:new_state[l:key]
      call add(l:unchecked['all'], l:key)
      if s:getitemstatus(l:key)
        call add(l:unchecked['new'], l:key)
      endif
    endif
  endfor
  return l:unchecked
endfunction

function! s:runcallbacks(items, event)
  if s:hascallback(a:event)
    let CallbackFunc = s:getcallback(a:event)
    for l:item in a:items
      call CallbackFunc(l:item)
    endfor
  endif
endfunction

" call the call back functions, passing the relevant items as an array,
" and then re-render the buffer
function! s:processchanges()
  " checked
  let l:checked = s:getchecked()
  call s:runcallbacks(l:checked['all'], 'checked')
  call s:runcallbacks(l:checked['new'], 'newchecked')
  " unchecked
  let l:unchecked = s:getunchecked()
  if s:iskeepchecked()
    call s:runcallbacks(l:unchecked['all'], 'unchecked')
    call s:runcallbacks(l:unchecked['new'], 'newunchecked')
    call s:setvalues(s:parsebuffer())
  else
    call s:setvalues(s:makevaluemap(l:unchecked['all']))
  endif
  call s:render()
endfunction

" run the write callback
function! multiselect#write()
  let destination = expand("<amatch>")
  if (fnamemodify(destination, ":t") == s:getname())
    call s:processchanges()
  else
    " if the name we're saving to doesn't match the buffer name, that means
    " we're doing an _actual_ save, and we should purge the multiselect buffer
    " which has now been replaced by a file
    let bang = v:cmdbang ? "!" : ""
    execute "saveas".bang." ".destination
    call s:purge()
  endif
endfunction

function! s:validateconfig(config)
  if ! has_key(a:config, 'name')
    throw "Missing mandatory config key 'name'"
  endif
  if has_key(a:config, 'onnewunchecked') && ! (has_key(a:config, 'keepchecked') && a:config['keepchecked'])
    throw "Must use 'keepchecked': 1 if using new unchecked handlers"
  end
endfunction

function! multiselect#open(values, config)
  call s:validateconfig(a:config)
  call s:createnew(a:values, a:config)
endfunction
