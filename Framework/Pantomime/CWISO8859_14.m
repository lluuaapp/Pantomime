#import "CWISO8859_14.h"

static struct charset_code code_table[]={
{0x20,0x0020}, {0x21,0x0021}, {0x22,0x0022}, {0x23,0x0023}, {0x24,0x0024}, 
{0x25,0x0025}, {0x26,0x0026}, {0x27,0x0027}, {0x28,0x0028}, {0x29,0x0029}, 
{0x2a,0x002a}, {0x2b,0x002b}, {0x2c,0x002c}, {0x2d,0x002d}, {0x2e,0x002e}, 
{0x2f,0x002f}, {0x30,0x0030}, {0x31,0x0031}, {0x32,0x0032}, {0x33,0x0033}, 
{0x34,0x0034}, {0x35,0x0035}, {0x36,0x0036}, {0x37,0x0037}, {0x38,0x0038}, 
{0x39,0x0039}, {0x3a,0x003a}, {0x3b,0x003b}, {0x3c,0x003c}, {0x3d,0x003d}, 
{0x3e,0x003e}, {0x3f,0x003f}, {0x40,0x0040}, {0x41,0x0041}, {0x42,0x0042}, 
{0x43,0x0043}, {0x44,0x0044}, {0x45,0x0045}, {0x46,0x0046}, {0x47,0x0047}, 
{0x48,0x0048}, {0x49,0x0049}, {0x4a,0x004a}, {0x4b,0x004b}, {0x4c,0x004c}, 
{0x4d,0x004d}, {0x4e,0x004e}, {0x4f,0x004f}, {0x50,0x0050}, {0x51,0x0051}, 
{0x52,0x0052}, {0x53,0x0053}, {0x54,0x0054}, {0x55,0x0055}, {0x56,0x0056}, 
{0x57,0x0057}, {0x58,0x0058}, {0x59,0x0059}, {0x5a,0x005a}, {0x5b,0x005b}, 
{0x5c,0x005c}, {0x5d,0x005d}, {0x5e,0x005e}, {0x5f,0x005f}, {0x60,0x0060}, 
{0x61,0x0061}, {0x62,0x0062}, {0x63,0x0063}, {0x64,0x0064}, {0x65,0x0065}, 
{0x66,0x0066}, {0x67,0x0067}, {0x68,0x0068}, {0x69,0x0069}, {0x6a,0x006a}, 
{0x6b,0x006b}, {0x6c,0x006c}, {0x6d,0x006d}, {0x6e,0x006e}, {0x6f,0x006f}, 
{0x70,0x0070}, {0x71,0x0071}, {0x72,0x0072}, {0x73,0x0073}, {0x74,0x0074}, 
{0x75,0x0075}, {0x76,0x0076}, {0x77,0x0077}, {0x78,0x0078}, {0x79,0x0079}, 
{0x7a,0x007a}, {0x7b,0x007b}, {0x7c,0x007c}, {0x7d,0x007d}, {0x7e,0x007e}, 
{0xa0,0x00a0}, {0xa1,0x1e02}, {0xa2,0x1e03}, {0xa3,0x00a3}, {0xa4,0x010a}, 
{0xa5,0x010b}, {0xa6,0x1e0a}, {0xa7,0x00a7}, {0xa8,0x1e80}, {0xa9,0x00a9}, 
{0xaa,0x1e82}, {0xab,0x1e0b}, {0xac,0x1ef2}, {0xad,0x00ad}, {0xae,0x00ae}, 
{0xaf,0x0178}, {0xb0,0x1e1e}, {0xb1,0x1e1f}, {0xb2,0x0120}, {0xb3,0x0121}, 
{0xb4,0x1e40}, {0xb5,0x1e41}, {0xb6,0x00b6}, {0xb7,0x1e56}, {0xb8,0x1e81}, 
{0xb9,0x1e57}, {0xba,0x1e83}, {0xbb,0x1e60}, {0xbc,0x1ef3}, {0xbd,0x1e84}, 
{0xbe,0x1e85}, {0xbf,0x1e61}, {0xc0,0x00c0}, {0xc1,0x00c1}, {0xc2,0x00c2}, 
{0xc3,0x00c3}, {0xc4,0x00c4}, {0xc5,0x00c5}, {0xc6,0x00c6}, {0xc7,0x00c7}, 
{0xc8,0x00c8}, {0xc9,0x00c9}, {0xca,0x00ca}, {0xcb,0x00cb}, {0xcc,0x00cc}, 
{0xcd,0x00cd}, {0xce,0x00ce}, {0xcf,0x00cf}, {0xd0,0x0174}, {0xd1,0x00d1}, 
{0xd2,0x00d2}, {0xd3,0x00d3}, {0xd4,0x00d4}, {0xd5,0x00d5}, {0xd6,0x00d6}, 
{0xd7,0x1e6a}, {0xd8,0x00d8}, {0xd9,0x00d9}, {0xda,0x00da}, {0xdb,0x00db}, 
{0xdc,0x00dc}, {0xdd,0x00dd}, {0xde,0x0176}, {0xdf,0x00df}, {0xe0,0x00e0}, 
{0xe1,0x00e1}, {0xe2,0x00e2}, {0xe3,0x00e3}, {0xe4,0x00e4}, {0xe5,0x00e5}, 
{0xe6,0x00e6}, {0xe7,0x00e7}, {0xe8,0x00e8}, {0xe9,0x00e9}, {0xea,0x00ea}, 
{0xeb,0x00eb}, {0xec,0x00ec}, {0xed,0x00ed}, {0xee,0x00ee}, {0xef,0x00ef}, 
{0xf0,0x0175}, {0xf1,0x00f1}, {0xf2,0x00f2}, {0xf3,0x00f3}, {0xf4,0x00f4}, 
{0xf5,0x00f5}, {0xf6,0x00f6}, {0xf7,0x1e6b}, {0xf8,0x00f8}, {0xf9,0x00f9}, 
{0xfa,0x00fa}, {0xfb,0x00fb}, {0xfc,0x00fc}, {0xfd,0x00fd}, {0xfe,0x0177}, 
{0xff,0x00ff}, };

@implementation CWISO8859_14

- (id) init
{
	return [super initWithCodeCharTable: code_table  length: sizeof(code_table)/sizeof(code_table[0])];
}

- (NSString *) name
{
	return @"iso-8859-14";
}

@end

