export Arch=i386
export Cpp=i686-elf-g++
export Asm=nasm
export Emu=qemu-system-$(Arch)

export Name=raw-boot

export DirArch=../$(Arch)
# export DirInclude=$(DirArch)/include
# export DirSource=$(DirArch)/source
export DirBoot=$(DirArch)/boot

# export SourcesCpp=$(shell find $(DirSource) -name '*.cpp')
# export SourcesAsm=$(shell find $(DirSource) -name '*.asm')
# export ObjectsCpp=$(SourcesCpp:.cpp=.cppo)
# export ObjectsAsm=$(SourcesAsm:.asm=.asmo)

export FlagsCompiler=-std=c++17 -ffreestanding -nostdlib -O2 -Wall -Wextra -fno-exceptions -fno-rtti -I $(DirInclude)
export FlagsLinker=-m16 -ffreestanding -O2 -nostdlib -T $(DirArch)/link.ld -lgcc
export FlagsEmu=-drive format=raw,file=$(Name).bin -m 2G -monitor stdio

all:
	# $(MAKE) $(ObjectsCpp)
	# $(MAKE) $(ObjectsAsm)
	# $(MAKE) kernel
	$(MAKE) boot

boot:
	$(Asm) -fbin $(DirBoot)/loader.asm -o loader.bin
	$(Asm) -fbin $(DirBoot)/$@.asm -o $(Name).bin

%.cppo:	%.cpp
	$(Cpp) -c $< $(FlagsCompiler) -o $@

%.asmo:	%.asm
	$(Asm) -felf $< -o $@

kernel:	$(ObjectsCpp) $(ObjectsAsm)
	$(Cpp) $^ $(FlagsLinker) -o $@.bin

run:
	$(Emu) $(FlagsEmu)

clean:
	rm -rf $(ObjectsCpp) $(ObjectsAsm) *.bin
