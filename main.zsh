#!/bin/zsh

jobs -Z jobs.zsh

ps -o pid,comm,args $$
nvim --cmd "echo nvim_get_proc($$)" --cmd quit
