import struct
import sys
import argparse

def float_to_binary(num):
    """Convert float number to IEEE 754 binary format"""
    return struct.pack('f', num)

def create_test_file(value1, value2):
    """Create binary file containing two float values"""
    with open('FLOAT2.BIN', 'wb') as f:
        f.write(float_to_binary(value1))
        f.write(float_to_binary(value2))
    print(f"Created FLOAT2.BIN with values: {value1} × {value2}")
    print("Binary representation:")
    print(f"Value 1: {format(struct.unpack('!I', float_to_binary(value1))[0], '032b')}")
    print(f"Value 2: {format(struct.unpack('!I', float_to_binary(value2))[0], '032b')}")

def generate_test_case(case):
    """Generate specific test case based on input parameter"""
    test_cases = {
        # Basic cases
        "basic1": (2.5, 3.25),         # Basic positive numbers
        "basic2": (2.5, -3.25),        # Mixed signs
        "basic3": (-2.5, -3.25),       # Both negative
        
        # Zero cases
        "zero1": (5.0, 0.0),          # Multiply with zero
        "zero2": (0.0, 0.0),          # Zero × Zero
        
        # Special numbers
        "inf": (float('inf'), 1.0),   # Infinity
        "nan": (float('nan'), 2.0),   # NaN
        
        # Underflow/Overflow cases
        "underflow": (1e-20, 1e-20),  # Very small numbers
        "overflow": (1e20, 1e20),     # Very large numbers
        
        # Denormalized numbers
        "denorm": (1e-45, 1.0),       # Denormalized × normal
        
        # Decimal numbers
        "decimal1": (1.5, 2.5),       # Both decimal
        "decimal2": (2.0, 1.5),       # Integer × decimal
        
        # Custom case format: custom_<num1>_<num2>
    }
    
    # Handle custom case
    if case.startswith("custom_"):
        try:
            # Format: custom_<num1>_<num2>
            _, num1, num2 = case.split('_')
            values = (float(num1), float(num2))
        except ValueError:
            print("Invalid custom case format. Use: custom_<num1>_<num2>")
            sys.exit(1)
    else:
        if case not in test_cases:
            print(f"Invalid test case. Available cases:")
            for key in test_cases.keys():
                print(f"- {key}")
            print("- custom_<num1>_<num2> (for custom values)")
            sys.exit(1)
        values = test_cases[case]
    
    create_test_file(*values)

def main():
    parser = argparse.ArgumentParser(description='Generate FLOAT2.BIN test file for MIPS float multiplication program')
    parser.add_argument('case', help='Test case identifier or custom_<num1>_<num2> for custom values')
    
    args = parser.parse_args()
    generate_test_case(args.case)

if __name__ == "__main__":
    main()