#!/bin/sh

ps -o pid,comm,args $$
nvim --cmd "echo nvim_get_proc($$)" --cmd quit
