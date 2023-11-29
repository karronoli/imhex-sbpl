#include <std/io.pat>
#include <std/math.pat>
#include <std/mem.pat>
#include <std/string.pat>
#include <std/sys.pat>

// Protocol code color
#define STXColor color("FF0000")
#define ESCColor color("00FFFF")
#define ETXColor color("FF0000")

// Command value color
#define ASCIIDecimalColor color("FFFFCC")
#define BarcodeColor color("808080")
#define BitmapColor color("808080")
#define DirectionColor color("FFFF99")
#define CommandCodeColor color("FFFF00")

enum EscapeSeq : u8 {
  STX = 0x02,
  ETX = 0x03,
  ESC = 0x1b,
};

enum SensorType : char {
  Reflection = '0',
  Transparent = '1',
  Ignore = '2',
};

enum CommandCode : str {
  A = "A",
  A1 = "A1",
  A3 = "A3",
  BG = "BG",
  CS = "CS",
  // #E = "#E", // Expected 'include', 'define' or 'pragma'
  Darkness = "#E",
  GM = "GM",
  H = "H",
  IG = "IG",
  Q = "Q",
  TG = "TG",
  V = "V",
  Z = "Z",
};

struct ASCIIDecimal<auto Size> {
  char value[Size] [[ASCIIDecimalColor]];
} [[sealed, format("format_ascii_decimal"), transform("format_ascii_decimal")]];

fn format_ascii_decimal(ASCIIDecimal<Size> ascii) {
  return std::string::parse_int(ascii.value, 10);
};

namespace Command {
  struct base<auto Size> {
    char command[Size] [[CommandCodeColor]];
  };

  struct A : base<1> {
    std::assert(std::format("{}", command) == CommandCode::A, "Invalid command");
  };

  struct A1 : base<2> {
    std::assert(std::format("{}", command) == CommandCode::A1, "Invalid command");

    ASCIIDecimal<4> height;
    std::assert(height > 0 && height <= 9999, "Invalid height");

    ASCIIDecimal<4> width;
    std::assert(width > 0 && width <= 9999, "Invalid width");
  };

  struct A3 : base<2> {
    std::assert(std::format("{}", command) == CommandCode::A3, "Invalid command");

    char direction1 [[DirectionColor]];
    ASCIIDecimal<4> length1;
    std::assert(std::math::abs(length1) <= 999, "Invalid length1");

    char direction2 [[DirectionColor]];
    ASCIIDecimal<4> length2;
    std::assert(std::math::abs(length1) <= 999, "Invalid length1");
  };

  struct BG : base<2> {
    std::assert(std::format("{}", command) == CommandCode::BG, "Invalid command");

    ASCIIDecimal<2> narrow_bar_width;
    std::assert(narrow_bar_width > 0 && narrow_bar_width <= 99,
      "Invalid narrow_bar_width");

    ASCIIDecimal<3> barcode_height;
    std::assert(barcode_height > 0 && barcode_height <= 999,
      "Invalid barcode_height");

    u8 barcode[while(read_u8($) != EscapeSeq::ESC)] [[BarcodeColor]];
    std::assert(sizeof(barcode) > 0, "Invalid barcode");
  };

  struct CS : base<2> {
    std::assert(std::format("{}", command) == CommandCode::CS, "Invalid command");

    ASCIIDecimal<2> speed;
    std::assert(speed > 0 && speed <= 99, "Invalid speed");
  };

  struct Darkness : base<2> {
    std::assert(std::format("{}", command) == CommandCode::Darkness, "Invalid command");

    ASCIIDecimal<1> darkness;
    std::assert(darkness > 0 && darkness <= 9, "Invalid density");

    char spec;
  };

  struct GM : base<2> {
    std::assert(std::format("{}", command) == CommandCode::GM, "Invalid command");

    ASCIIDecimal<5> length;
    std::assert(length > 0 && length <= 99999, "Invalid length");

    padding[1];

    u8 bitmap[length] [[BitmapColor]];
  };

  struct H : base<1> {
    std::assert(std::format("{}", command) == CommandCode::H, "Invalid command");

    ASCIIDecimal<4> position;
    std::assert(position > 0 && position <= 9999, "Invalid position");
  };

  struct IG : base<2> {
    std::assert(std::format("{}", command) == CommandCode::IG, "Invalid command");

    SensorType;
  };

  struct Q : base<1> {
    std::assert(std::format("{}", command) == CommandCode::Q, "Invalid command");

    ASCIIDecimal<6> count;
    std::assert(count > 0 && count <= 999999, "Invalid count");
  };

  struct TG : base<2> {
    std::assert(std::format("{}", command) == CommandCode::TG, "Invalid command");

    ASCIIDecimal<2> gap;
    std::assert(gap > 0 && gap <= 99, "Invalid gap");
  };

  struct V : base<1> {
    std::assert(std::format("{}", command) == CommandCode::V, "Invalid command");

    ASCIIDecimal<4> position;
    std::assert(position > 0 && position <= 9999, "Invalid position");
  };

  struct Z : base<1> {
    std::assert(std::format("{}", command) == CommandCode::Z, "Invalid command");
  };
}

fn read_u8(u32 address) {
  u8 value @ address;

  return value;
};

fn cmd_len() {
  u32 offset = $;
  u32 address = $;
  u8 value = read_u8(address);
  str command = str(value);

  while (value != EscapeSeq::ESC) {
    address = address + 1;
    value = read_u8(address);

    if (value == EscapeSeq::ETX) break;

    command += str(value);

    if (command == CommandCode::GM) {
      str gm_length_ascii = std::mem::read_string(address + 1, 5);
      u32 gm_length = std::string::parse_int(gm_length_ascii, 10);

      return std::string::length("GM01234,") + gm_length;
    }
  }

  return address - offset;
};

// Convert byte array to Instruction struct.
union CommandParser {
  u32 cmd_len = cmd_len();
  u8 command[cmd_len] [[hidden]];

  str code1 = str(command[0]);

  // A & Z command

  if (cmd_len == 1) {
    match (code1) {
      (CommandCode::A): Command::A;
      (CommandCode::Z): Command::Z;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  str code2 = code1 + str(command[1]);

  // variable length command

  if (cmd_len > std::string::length("BG01234")
      && code2 == CommandCode::BG) {
    Command::BG;
    return;
  }

  if (cmd_len > std::string::length("GM01234,")
      && code2 == CommandCode::GM) {
    Command::GM;
    return;
  }

  // fixed length command

  if (cmd_len == 2) {
    std::error("Unknown command. input: " + std::format("{}", command));
  }

  if (cmd_len == 3) {
    match (code2) {
      (CommandCode::IG): Command::IG;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  if (cmd_len == 4) {
    match (code2) {
      (CommandCode::CS): Command::CS;
      (CommandCode::TG): Command::TG;
      (CommandCode::Darkness): Command::Darkness;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  if (cmd_len == 5) {
    match (code1) {
      (CommandCode::H): Command::H;
      (CommandCode::V): Command::V;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  if (cmd_len == 7) {
    match (code1) {
      (CommandCode::Q): Command::Q;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  if (cmd_len == 10) {
    match (code2) {
      (CommandCode::A1): Command::A1;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  if (cmd_len == 12) {
    match (code2) {
      (CommandCode::A3): Command::A3;
      (_): std::error("Unknown command. input: " + std::format("{}", command));
    }
    return;
  }

  std::error("Unknown command. input: " + std::format("{}", command));
};

struct Instruction {
  EscapeSeq esc [[ESCColor]];
  std::assert(esc == EscapeSeq::ESC, "Invalid escape sequence");

  CommandParser [[inline]];
};

struct SBPL {
  Instruction instructions[while(read_u8($) != EscapeSeq::ETX)];
};

u8 STX @ 0x0 [[STXColor]];
SBPL sbpl @ 0x1 [[inline]];
u8 ETX @ $ [[EXTColor]];