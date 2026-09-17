package main

import (
	"fmt"

	"golang.org/x/sys/unix"
)

func gostr_from_cstr(cstr []byte) string {
	for n := 0; n < len(cstr); n++ {
		if cstr[n] == 0x00 {
			return string(cstr[:n])
		}
	}
	return ""
}

func main() {
	info, err := Get_uts_data()
	if err != nil {
		fmt.Println("[ERROR] %s", err)
	}
	fmt.Printf("Hello world, from %s %s %s (%s)\n",
		info.machine,
		info.sys_name,
		info.node_name,
		info.release)
}

type UtsData struct {
	sys_name  string
	node_name string
	release   string
	version   string
	machine   string
	domain    string
}

func Get_uts_data() (UtsData, error) {
	var uts unix.Utsname
	var data UtsData
	err := unix.Uname(&uts)

	if err == nil {
		data.sys_name = gostr_from_cstr(uts.Sysname[:])
		data.node_name = gostr_from_cstr(uts.Nodename[:])
		data.release = gostr_from_cstr(uts.Release[:])
		data.version = gostr_from_cstr(uts.Version[:])
		data.machine = gostr_from_cstr(uts.Machine[:])
		data.domain = gostr_from_cstr(uts.Domainname[:])
	}

	return data, err
}
