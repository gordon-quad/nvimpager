#!/bin/sh

printf 1:
ps -o pid=,comm=,cmd= $$
printf 2:
ps -o pid=,comm=,cmd= $(ps -o ppid= $$)
printf 2:
ps -o pid=,comm=,cmd= $(ps -o ppid= $(ps -o ppid= $$))

ps -o pid,ppid,comm,cmd

nvim --cmd "echo nvim_get_proc($$)" --cmd q
