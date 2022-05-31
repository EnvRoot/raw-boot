ENTRY(entry)
OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)
SECTIONS {
	. = 0x600;
	__external_start = .;

	.head :
	{
		LONG(entry)
		LONG(__external_end - __external_start)
	}

	.text :
	{
		*(.text)
	}

	.data :
	{
		*(.data)
		*(.rodata)
		*(.bss)
	}

	__external_end = .;
}