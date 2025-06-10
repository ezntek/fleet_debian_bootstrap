# fleet laptop bootstrapper

Bootstraps a themed debian-testing installation for use on the marcosian fleet laptops.

## usage

 * get the script somehow (download it?)
 * boot into a GUI debian live cd because dependencies and stuff
 * run the script as root
 * ???
 * profit

## dependencies

* `debootstrap`
* `dosfstools`
* some other ones 

## background (for non marcosians)

There is a teacher at our school called Mr. Marcos. He teaches computer science at our school, and his computer lab is open to almost all programmers in the school who wishes to come during breaks, before and after school. Some people in our community call it marcosia, hence the name. Why? it is very easy to say.

He also supervises a programming club that I (as of 2025) and a few others are in charge of, where we teach people programming. However, many people don't actually want to install a programming toolchain on their system (due to time constraints, as we only get 40 minutes a week, parental controls or otherwise). Since the school computer lab computers are crippled, for the following reasons:

* hardware is ancient (skylake? kaby lake? iMacs with 21.5" screens)
* they run macOS 12 "Monterey" (so very slow and old and laggy)
* ***no comprehensive programming toolchain*** (why the hell do computers in a coding lab not have a C compiler and an up to date python interpeter)
* horrible keyboards & mice
* bad placement (these iMacs are placed _around_ the classroom and students therefore cannot listen to club instructors and code at the same time)

The students (myself and friends who don't code) have collectively purchased, refurbished, installed SSDs, batteries, an adequate amount of RAM and [librebooted](https://libreboot.org) 4 ThinkPad X230s. We also have a T460 in the fleet, with more models coming.

These will have a full tinkerable linux environment (no root access however) that will hopefully have full guest user temporary home dir functionality, proper IDEs and an up-to-date programming toolchain, and can be taken around the classroom. This is in hopes to provide a sane alternative to the school iMacs.

However, I have to put some OS on it. After trying to deploy mint to one machine, I have decided it's too clunky to have to use CloneZilla on our SSDs. I therefore have created this script that bootstraps a minimal debian system with cinnamon, fully themed, that is ready to be run on any one of the thinkpads to be converted into a "fleet laptop" (borrowable laptop for programmers/club members).

## features

* absolutely no error handling (the script continues on errors)
* wonderful uncommented "code"
* sketchy way of continuing execution in a chroot
* absolutely 0 logging

## bundled software

* a C compiler
* a JDK
* a Python interpreter
* geany
* thonny
* chromium
* Bibata + Mint-Y icons/gtk theme (to make it look like mint)
* everything from the debian "standard" software suite (from `tasksel install standard`)
