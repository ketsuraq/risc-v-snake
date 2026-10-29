from pathlib import Path
import re
import sys

R_OPS = {
    'add': (0, 0), 'sub': (0, 0x20), 'sll': (1, 0),
    'slt': (2, 0), 'sltu': (3, 0), 'xor': (4, 0),
    'srl': (5, 0), 'sra': (5, 0x20), 'or': (6, 0), 'and': (7, 0),
}
I_OPS = {'addi': 0, 'slti': 2, 'sltiu': 3, 'xori': 4, 'ori': 6, 'andi': 7}
SHIFT_OPS = {'slli': (1, 0), 'srli': (5, 0), 'srai': (5, 0x20)}
LOAD_OPS = {'lb': 0, 'lh': 1, 'lw': 2, 'lbu': 4, 'lhu': 5}
STORE_OPS = {'sb': 0, 'sh': 1, 'sw': 2}
BRANCH_OPS = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}


def reg(token):
    if not re.fullmatch(r'x(?:[0-9]|[12][0-9]|3[01])', token.lower()):
        raise ValueError(f'invalid register: {token} (use x0..x31)')
    return int(token[1:])


def number(token):
    try:
        # decimal including leading zeros; hex 0x...; binary 0b...
        return int(token, 0) if token.lower().startswith(('0x', '-0x', '+0x', '0b', '-0b', '+0b')) else int(token, 10)
    except ValueError as exc:
        raise ValueError(f'invalid number: {token}') from exc


def signed(value, bits, what):
    if not -(1 << (bits - 1)) <= value < (1 << (bits - 1)):
        raise ValueError(f'{what} must fit signed {bits} bits: {value}')
    return value & ((1 << bits) - 1)


def offset(token, labels, pc):
    # branch/jump label is PC-relative; numeric operands are already offsets
    return labels[token] - pc if token in labels else number(token)


def memory_arg(token):
    match = re.fullmatch(r'(.+?)\((x(?:[0-9]|[12][0-9]|3[01]))\)', token, re.I)
    if not match:
        raise ValueError(f'expected offset(register), got: {token}')
    return number(match.group(1)), reg(match.group(2))


def encode(text, labels, pc):
    parts = text.replace(',', ' ').split()
    op, a = parts[0].lower(), parts[1:]

    def nargs(n):
        if len(a) != n:
            raise ValueError(f'{op} expects {n} operand(s), got {len(a)}')

    if op in R_OPS:
        nargs(3)
        rd, rs1, rs2 = map(reg, a)
        f3, f7 = R_OPS[op]
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33

    if op in I_OPS:
        nargs(3)
        rd, rs1 = reg(a[0]), reg(a[1])
        imm = signed(number(a[2]), 12, op + ' immediate')
        return (imm << 20) | (rs1 << 15) | (I_OPS[op] << 12) | (rd << 7) | 0x13

    if op in SHIFT_OPS:
        nargs(3)
        rd, rs1, shamt = reg(a[0]), reg(a[1]), number(a[2])
        if not 0 <= shamt <= 31:
            raise ValueError('shift amount must be 0..31')
        f3, f7 = SHIFT_OPS[op]
        return (f7 << 25) | (shamt << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x13

    if op in LOAD_OPS:
        nargs(2)
        rd = reg(a[0])
        imm, rs1 = memory_arg(a[1])
        imm = signed(imm, 12, 'load offset')
        return (imm << 20) | (rs1 << 15) | (LOAD_OPS[op] << 12) | (rd << 7) | 0x03

    if op in STORE_OPS:
        nargs(2)
        rs2 = reg(a[0])
        imm, rs1 = memory_arg(a[1])
        imm = signed(imm, 12, 'store offset')
        return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (STORE_OPS[op] << 12) | ((imm & 31) << 7) | 0x23

    if op in BRANCH_OPS:
        nargs(3)
        rs1, rs2 = reg(a[0]), reg(a[1])
        imm = offset(a[2], labels, pc)
        if imm % 2:
            raise ValueError('branch offset must be even')
        imm = signed(imm, 13, 'branch offset')
        return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (BRANCH_OPS[op] << 12) | (((imm >> 1) & 15) << 8) | (((imm >> 11) & 1) << 7) | 0x63

    if op == 'jal':
        nargs(2)
        rd = reg(a[0])
        imm = offset(a[1], labels, pc)
        if imm % 2:
            raise ValueError('jump offset must be even')
        imm = signed(imm, 21, 'jump offset')
        return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 1023) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 255) << 12) | (rd << 7) | 0x6F

    if op == 'jalr':
        nargs(2)
        rd = reg(a[0])
        imm, rs1 = memory_arg(a[1])
        imm = signed(imm, 12, 'jalr offset')
        return (imm << 20) | (rs1 << 15) | (rd << 7) | 0x67

    if op in ('lui', 'auipc'):
        nargs(2)
        rd, imm = reg(a[0]), number(a[1])
        # U-type operand is the upper 20-bit field, like `lui x1, 0x1`.
        if not -(1 << 19) <= imm <= 0xFFFFF:
            raise ValueError('U-type immediate must fit 20 bits')
        return ((imm & 0xFFFFF) << 12) | (rd << 7) | (0x37 if op == 'lui' else 0x17)

    if op == 'fence':
        nargs(0)
        return 0x0000000F
    if op == 'ecall':
        nargs(0)
        return 0x00000073
    if op == 'ebreak':
        nargs(0)
        return 0x00100073

    raise ValueError(f'unknown instruction: {op}')


def assemble_file(source, destination):
    labels = {}
    instructions = []
    pc = 0

    # pass 1: find labels and instruction addresses
    for line_number, raw in enumerate(source.read_text().splitlines(), start=1):
        line = raw.split('#', 1)[0].split('//', 1)[0].strip().lower()
        while ':' in line:
            label, line = (part.strip() for part in line.split(':', 1))
            if not re.fullmatch(r'[a-z_][a-z0-9_]*', label):
                raise ValueError(f'line {line_number}: invalid label: {label}')
            if label in labels:
                raise ValueError(f'line {line_number}: duplicate label: {label}')
            labels[label] = pc
        if line:
            instructions.append((line_number, pc, line))
            pc += 4

    if len(instructions) > 256:
        raise ValueError('program exceeds your current 256-word instruction memory')

    # pass 2: encode with labels resolved
    result = []
    for line_number, pc, line in instructions:
        try:
            result.append(encode(line, labels, pc))
        except ValueError as exc:
            raise ValueError(f'line {line_number}: {exc}') from exc

    destination.write_text(''.join(f'{word:08X}\n' for word in result))
    print(f'assembled {len(result)} instructions into {destination}')


if __name__ == '__main__':
    folder = Path(__file__).resolve().parent
    source = folder / (sys.argv[1] if len(sys.argv) > 1 else 'snake.asm')
    assemble_file(source, folder / 'program.mem')