ENTRY(entry)
OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)
SECTIONS {
	. = 0x2000;
	__external_start = .;

	.head :
	{
		QUAD(0x36384E4942545845)		/*EXTBIN86*/
		LONG(__external_start)		/*SOF*/
		LONG(__external_end)			/*EOF*/
		LONG(entry)								/*EP*/
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
