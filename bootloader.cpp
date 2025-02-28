#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <vector>
#include <unordered_map>
#include <thread>
#include <regex>
#include <termios.h>
#include <unistd.h>

enum class cpu_instruction_t {
    cpu_exec = 0,
    copy_from_to_address = 1,
    read_from_address = 2,
    jump = 3,
    jump_if = 4,
    jump_if_not = 5,
    jump_err = 6
};

enum class cpu_operation_t {
    add = 0,
    sub = 1,
    incr = 2,
    decr = 3,
    div = 4,
    mod = 5,
    mul = 6,
    is_num = 7,
    cmp_eq = 8,
    cmp_neq = 9,
    cmp_lt = 10,
    cmp_le = 11,
    contains = 12,
    get_length = 13,
    starts_with = 14,
    get_column = 15,
    replace_column = 16,
    concat_with = 17,
    read_input = 18,
    display = 19,
    display_ln = 20,
    read_block = 21,
    write_block = 22,
    set_background_color = 23,
    render_bitmap = 24,
    // 25, 26 are reserved for future use
    encrypt_data = 27,
    decrypt_data = 28,
    nop = 29,
    halt = 30,
    unknown = 31
};

enum class address_t {
    info_op = 1,
    op = 2,

    info_a = 3,
    a = 4,
    info_b = 5,
    b = 6,
    info_c = 7,
    c = 8,
    info_d = 9,
    d = 10,

    info_res = 11,
    res = 12,
    info_bool_res = 13,
    bool_res = 14,

    info_error = 15,
    error = 16,

    info_display_buffer = 17,
    display_buffer = 18,
    info_display_color = 19,
    display_color = 20,

    info_keyboard_buffer = 21,
    keyboard_buffer = 22,

    info_display_background = 23,
    display_background = 24,

    info_program_counter = 25,
    program_counter = 26,

    info_free_memory_start = 27,
    free_memory_start = 28,
    info_free_memory_end = 29,
    free_memory_end = 30,
    info_free_chunks = 31,
    free_chunks = 32,

    info_kernel_start = 40,
    kernel_start = 41,
};

enum class display_color_t {
    no = 0,
    green = 1,
    yellow = 2,
    red = 3,
    black = 4,
    blue = 5,
    magenta = 6,
    cyan = 7,
    white = 8
};

const std::unordered_map<std::string, std::string> background_color_map = {
    {"g", "\033[42m"}, {"y", "\033[43m"}, {"r", "\033[41m"}, {"B", "\033[40m"},
    {"b", "\033[44m"}, {"m", "\033[45m"}, {"c", "\033[46m"}, {"w", "\033[47m"},
    {std::to_string(static_cast<int>(display_color_t::green)), "\033[42m"},
    {std::to_string(static_cast<int>(display_color_t::yellow)), "\033[43m"},
    {std::to_string(static_cast<int>(display_color_t::red)), "\033[41m"},
    {std::to_string(static_cast<int>(display_color_t::black)), "\033[40m"},
    {std::to_string(static_cast<int>(display_color_t::blue)), "\033[44m"},
    {std::to_string(static_cast<int>(display_color_t::magenta)), "\033[45m"},
    {std::to_string(static_cast<int>(display_color_t::cyan)), "\033[46m"},
    {std::to_string(static_cast<int>(display_color_t::white)), "\033[47m"}
};

std::string get_background_color(const std::string& color) {
    auto it = background_color_map.find(color);
    return (it != background_color_map.end()) ? it->second : "\033[40m";
}

namespace keyboard_mode {
    constexpr std::string_view read_line = "KeyboardReadLine";
    constexpr std::string_view read_line_silently = "KeyboardReadLineSilently";
    constexpr std::string_view read_char = "KeyboardReadChar";
    constexpr std::string_view read_char_silently = "KeyboardReadCharSilently";
}

std::vector<std::string> RAM_data;

std::string read_from_address(address_t reg) {
    return RAM_data[static_cast<int>(reg)];
}

std::string read_from_address(const std::string& line_no_str) {
    auto line_no = static_cast<int>(std::stoi(line_no_str));
    if (line_no < 1 || line_no > RAM_data.size()) {
        std::cerr << "Access to an invalid address " << line_no << std::endl;
        exit(1);
    }

    return RAM_data[line_no];
}

void write_to_address(address_t reg, const std::string& value) {
    RAM_data[static_cast<int>(reg)] = value;
}

void write_to_address(const std::string& line_no_str, const std::string& value) {
    auto line_no = static_cast<int>(std::stoi(line_no_str));
    if (line_no < 1 || line_no > RAM_data.size()) {
        std::cerr << "Access to an invalid address " << line_no << std::endl;
        exit(1);
    }

    RAM_data[line_no] = value;
}

void copy_from_to_address(const std::string& src, const std::string& dest) {
    std::string src_addr = src;
    std::string dest_addr = dest;
    if (src.empty() || dest.empty()) {
        std::cerr << "Invalid addresses for copy_from_to_address" << std::endl;
        exit(1);
    }

    if (src[0] == '*') {
        src_addr = read_from_address(src.substr(1));
    }

    if (dest[0] == '*') {
        dest_addr = read_from_address(dest.substr(1));
    }

    if (src[0] == '@') {
        write_to_address(dest_addr, src.substr(1));
    } else {
        write_to_address(dest_addr, read_from_address(src_addr));
    }
}

void jump_next() {
    int program_counter = std::stoi(read_from_address(address_t::program_counter));
    write_to_address(address_t::program_counter, std::to_string(program_counter + 1));
}

void jump(const std::string& address) {
    std::string_view address_view(address);
    if (address_view[0] == '*') {
        address_view = read_from_address(address_view.substr(1).data());
    }
    int address_int = std::stoi(address[0] == '*'
                                ? read_from_address(address.substr(1)).data()
                                : address);
    RAM_data[static_cast<int>(address_t::program_counter)] = std::to_string(address_int - 1);
}

void jump_if(const std::string& address) {
    if (read_from_address(address_t::bool_res) == "1") {
        jump(address);
    }
}

void jump_if_not(const std::string& address) {
    if (read_from_address(address_t::bool_res) == "0") {
        jump(address);
    }
}

void jump_err(const std::string& address) {
    if (! read_from_address(address_t::error).empty()) {
        jump(address);
    }
}

void jump_print_debug_info() {
    int next_cmd_address = std::stoi(read_from_address(address_t::program_counter));
    std::string next_cmd = read_from_address(std::to_string(next_cmd_address));

    std::cout << "\033[34m[DEBUG] Command " << next_cmd_address 
              << ":\033[35m " << next_cmd << "\033[0m" << std::endl;
}

constexpr const char* RAM_DUMP_FILE = "tmp/RAM.txt";

void dump_RAM_to_file() {
    std::ofstream file(RAM_DUMP_FILE);
    if (!file) {
        std::cerr << "Error: Unable to open " << RAM_DUMP_FILE << " for writing!" << std::endl;
        return;
    }

    for (auto it = RAM_data.begin() + 1; it != RAM_data.end(); it++) {
        file << *it << '\n';
    }
}

std::optional<std::string> read_disk_block(const std::string& disk_name, int block_number) {
    std::ifstream file("hw/" + disk_name);
    if (!file) {
        return std::nullopt;
    }
    std::string line;
    if (block_number < 1 || !std::getline(file, line)) {
        return std::nullopt;
    }
    int block_count = std::stoi(line);
    if (block_number > block_count) {
        return std::nullopt;
    }

    for (int i = 2; i <= block_number; ++i) {
        if (!std::getline(file, line)) {
            return std::nullopt;
        }
    }
    return line;
}

bool write_disk_block(const std::string& disk_name, int block_number, const std::string& data) {
    std::cout << "Writing to disk hw/" << disk_name << " block " << block_number << " data:" << data << std::endl;
    std::vector<std::string> lines;
    std::ifstream file_in("hw/" + disk_name);
    if (file_in.is_open()) {
        std::string line;
        while (std::getline(file_in, line)) {
            lines.push_back(line);
        }
    } else {
        return false;
    }
    file_in.close();

    int block_count = std::stoi(lines[0]);
    // We cannot rewrite block 1 with disk size
    if (block_number < 2 || block_number >= block_count) {
        return false;
    }

    lines[block_number - 1] = data;
    std::ofstream file_out("hw/" + disk_name);
    for (const auto& l : lines) {
        file_out << l << "\n";
    }
    return true;
}

void render_bitmap(int start, int end) {
    for (int i = start; i < end; ++i) {
        std::string bitmap_line = read_from_address(std::to_string(i));
        std::string bitmap_line_decoded;
        for (size_t j = 0; j < bitmap_line.length(); j += 1) {
            auto it = background_color_map.find(bitmap_line.substr(j, 1));
            bitmap_line_decoded += (it != background_color_map.end() ? it->second : read_from_address(address_t::display_background)) + " ";
        }
        std::cout << bitmap_line_decoded << std::endl;
    }
}

std::string to_string_no_trailing_zeros(double value) {
    std::ostringstream out;
    out.precision(10);  // Встановлюємо максимальну точність
    out << std::fixed << value;

    std::string result = out.str();
    
    // Видаляємо зайві нулі та можливу десяткову крапку в кінці
    result.erase(result.find_last_not_of('0') + 1, std::string::npos);
    if (result.back() == '.') {
        result.pop_back();
    }

    return result;
}

char get_char_no_enter(bool echo = false) {
    struct termios oldt, newt;
    char ch = '\0';

    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON);
    if (!echo) {
        newt.c_lflag &= ~ECHO;
    }
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);

    read(STDIN_FILENO, &ch, 1);

    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);

    if (echo) std::cout << ch;
    return ch;
}

void cpu_exec() {
    auto reg_op = static_cast<cpu_operation_t>(std::stoi(read_from_address(address_t::op)));
    auto reg_a = read_from_address(address_t::a);
    auto reg_b = read_from_address(address_t::b);
    auto reg_c = read_from_address(address_t::c);
    auto reg_d = read_from_address(address_t::d);

    write_to_address(address_t::error, ""); // Очистка REG_ERROR перед виконанням

    switch (reg_op) {
        case cpu_operation_t::add:
            if (reg_a.find_first_of(".") != std::string::npos || reg_b.find_first_of(".") != std::string::npos) {
                write_to_address(address_t::res, to_string_no_trailing_zeros(std::stod(reg_a) + std::stod(reg_b)));
            } else {
                write_to_address(address_t::res, std::to_string(std::stoi(reg_a) + std::stoi(reg_b)));
            }
            break;
        case cpu_operation_t::sub:
            if (reg_a.find_first_of(".") != std::string::npos || reg_b.find_first_of(".") != std::string::npos) {
                write_to_address(address_t::res, to_string_no_trailing_zeros(std::stod(reg_a) - std::stod(reg_b)));
            } else {
                write_to_address(address_t::res, std::to_string(std::stoi(reg_a) - std::stoi(reg_b)));
            }
            break;
        case cpu_operation_t::incr:
        {
            std::string result = reg_a.find_first_of(".") != std::string::npos
                                ? to_string_no_trailing_zeros(std::stod(reg_a) + 1)
                                : std::to_string(std::stoi(reg_a) + 1);
            write_to_address(address_t::res, result);
            break;
        }
        case cpu_operation_t::decr:
        {
            std::string result = reg_a.find_first_of(".") != std::string::npos
                    ? to_string_no_trailing_zeros(std::stod(reg_a) - 1)
                    : std::to_string(std::stoi(reg_a) - 1);
            write_to_address(address_t::res, result);
            break;
        }
        case cpu_operation_t::div:
            if (std::stoi(reg_b) == 0) {
                write_to_address(address_t::error, "Division by zero");
            } else {
                if (reg_a.find_first_of(".") != std::string::npos || reg_b.find_first_of(".") != std::string::npos) {
                    write_to_address(address_t::res, to_string_no_trailing_zeros(std::stod(reg_a) / std::stod(reg_b)));
                } else {
                    write_to_address(address_t::res, std::to_string(std::stoi(reg_a) / std::stoi(reg_b)));
                }
            }
            break;
        case cpu_operation_t::mod:
            if (std::stoi(reg_b) == 0) {
                write_to_address(address_t::error, "Modulo by zero");
            } else {
                write_to_address(address_t::res, std::to_string(std::stoi(reg_a) % std::stoi(reg_b)));
            }
            break;
        case cpu_operation_t::mul:
            if (reg_a.find_first_of(".") != std::string::npos || reg_b.find_first_of(".") != std::string::npos) {
                write_to_address(address_t::res, to_string_no_trailing_zeros(std::stod(reg_a) * std::stod(reg_b)));
            } else {
                write_to_address(address_t::res, std::to_string(std::stoi(reg_a) * std::stoi(reg_b)));
            }
            break;
        case cpu_operation_t::is_num:
            static const std::regex number_regex(R"(^-?\d*(\.\d+)?$)");
            write_to_address(address_t::bool_res, std::regex_match(reg_a, number_regex) ? "1" : "0");
            break;
        case cpu_operation_t::cmp_eq:
            write_to_address(address_t::bool_res, reg_a == reg_b ? "1" : "0");
            break;
        case cpu_operation_t::cmp_neq:
            write_to_address(address_t::bool_res, reg_a != reg_b ? "1" : "0");
            break;
        case cpu_operation_t::cmp_lt:
            write_to_address(address_t::bool_res, std::stoi(reg_a) < std::stoi(reg_b) ? "1" : "0");
            break;
        case cpu_operation_t::cmp_le:
            write_to_address(address_t::bool_res, std::stoi(reg_a) <= std::stoi(reg_b) ? "1" : "0");
            break;
        case cpu_operation_t::contains:
            write_to_address(address_t::bool_res, reg_a.find(reg_b) != std::string::npos ? "1" : "0");
            break;
        case cpu_operation_t::get_length:
            write_to_address(address_t::res, std::to_string(reg_a.length()));
            break;
        case cpu_operation_t::starts_with:
        {
            const auto b_length = reg_b.length();
            const auto found = reg_a.length() >= b_length && reg_a.substr(0, b_length) == reg_b;
            write_to_address(address_t::bool_res, found ? "1" : "0");
            write_to_address(address_t::res, found ? reg_a.substr(b_length) : "");
            break;
        }
        case cpu_operation_t::get_column:
        {
            std::string result;
            int column_index = std::stoi(reg_b);
            
            if (reg_c.empty()) {
                // If no delimiter is provided, return the reg_b-th character (1-based index)
                if (column_index > 0 && column_index <= static_cast<int>(reg_a.length())) {
                    result = std::string(1, reg_a[column_index - 1]);
                } else {
                    result = ""; // Return empty string if index is out of bounds
                }
            } else {
                // Tokenize by delimiter from reg_c
                size_t start = 0, end;
                std::string token;
                int column_index = std::stoi(reg_b);
                
                for (int i = 1; i <= column_index; ++i) {
                    end = reg_a.find(reg_c, start);
                    if (end == std::string::npos) {
                        token = (i == column_index) ? reg_a.substr(start) : ""; // Return last token or empty if out of bounds
                        break;
                    }
                    token = reg_a.substr(start, end - start);
                    start = end + reg_c.length();
                }
                result = token;
            }
            
            write_to_address(address_t::res, result);
            break;
        }
        case cpu_operation_t::replace_column: {
            int column_index = std::stoi(reg_b);
            std::string result = reg_a;
            
            if (reg_c.empty()) {
                // If no delimiter is provided, replace the reg_b-th character
                if (column_index > 0) {
                    // TODO test case: replace with empty string and empty delimiter
                    result = result.substr(0, column_index - 1)
                            + reg_d
                            + ((column_index < static_cast<int>(reg_a.length())) ? result.substr(column_index) : "");
                }
            } else {
                // Tokenize by delimiter from reg_c
                size_t start = 0, end;
                int column_index = std::stoi(reg_b);

                for (int i = 1; i < column_index; ++i) {
                    start = result.find(reg_c, start);
                    if (start == std::string::npos) {
                        result += reg_c + reg_d;
                        write_to_address(address_t::res, result);
                        return;
                    }
                    start += reg_c.length();
                }
                
                end = result.find(reg_c, start);
                if (end == std::string::npos) {
                    result.replace(start, std::string::npos, reg_d); // Replace till end if last column
                } else {
                    result.replace(start, end - start, reg_d);
                }
            }
            
            write_to_address(address_t::res, result);
            break;
        }
        case cpu_operation_t::concat_with:
            write_to_address(address_t::res, reg_a + reg_c + reg_b);
            break;
        case cpu_operation_t::read_input:
        {
            std::string input;
            if (reg_a == keyboard_mode::read_line || reg_a == keyboard_mode::read_line_silently) {
                std::getline(std::cin, input);
            } else if (reg_a == keyboard_mode::read_char || reg_a == keyboard_mode::read_char_silently) {
                input = std::string(1, get_char_no_enter(reg_a == keyboard_mode::read_char));
            } else {
                std::getline(std::cin, input);
            }
            write_to_address(address_t::keyboard_buffer, input);
            break;
        }
        case cpu_operation_t::display:
        case cpu_operation_t::display_ln:
        {
            std::string text_val = read_from_address(address_t::display_buffer);
            std::string color_val = read_from_address(address_t::display_color);
            std::string start_color, end_color = "\033[0m";
            display_color_t color_code = color_val.empty()
                                 ? display_color_t::no
                                 : static_cast<display_color_t>(std::stoi(color_val));
            if (color_code == display_color_t::green) start_color = "\033[92m";
            else if (color_code == display_color_t::yellow) start_color = "\033[93m";
            else if (color_code == display_color_t::red) start_color = "\033[91m";
            else if (color_code == display_color_t::black) start_color = "\033[90m";
            else if (color_code == display_color_t::blue) start_color = "\033[94m";
            else if (color_code == display_color_t::magenta) start_color = "\033[95m";
            else if (color_code == display_color_t::cyan) start_color = "\033[96m";
            else if (color_code == display_color_t::white) start_color = "\033[97m";
            else if (color_code == display_color_t::no) start_color = "";
            
            std::cout << start_color << text_val << end_color;
            if (reg_op == cpu_operation_t::display_ln) {
                std::cout << std::endl;
            }
            std::cout << std::flush;
            break;
        }
        case cpu_operation_t::read_block:
        {
            auto read_result = read_disk_block(reg_a, std::stoi(reg_b));
            write_to_address(address_t::res, read_result ? read_result.value() : "");
            write_to_address(address_t::error, read_result ? "" : "Error during block read");
            break;
        }
        case cpu_operation_t::write_block:
            write_to_address(address_t::error, write_disk_block(reg_a, std::stoi(reg_b), reg_c) ? "" : "Error during block write");
            break;
        case cpu_operation_t::set_background_color:
            std::cout << get_background_color(read_from_address(address_t::display_background)) << std::flush;
            break;
        case cpu_operation_t::render_bitmap:
            std::cout << "\033[2J\033[H" << std::flush;
            render_bitmap(std::stoi(reg_a), std::stoi(reg_b));
            break;
        case cpu_operation_t::encrypt_data:
            write_to_address(address_t::res, reg_a);
            break;
        case cpu_operation_t::decrypt_data:
            write_to_address(address_t::res, reg_a);
            break;
        case cpu_operation_t::nop:
        {
            double seconds = std::stod(reg_a);
            auto delay = std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::duration<double>(seconds)
            );
            std::this_thread::sleep_for(delay);
            break;
        }
        case cpu_operation_t::halt:
            std::cout << "CPU Halted" << std::endl;
            exit(0);
        default:
            std::cout << "[INFO] Executing " << static_cast<int>(reg_op) << ": Unknown command" << std::endl;
            exit(1);
    }
}


int main(int argc, char* argv[]) {
    if (argc != 3 && argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <kernel_file_name> <ram_size>" << std::endl;
        return 1;
    }

    // file and ram size
    std::string file_name = argv[1];
    int ram_size = std::stoi(argv[2]);
    RAM_data.resize(ram_size + 1, "0");
    bool debug_on = false;
    if (argc == 4 && std::string(argv[3]) == "-d") {
        debug_on = true;
    }

    // Let's load the kernel into RAM starting from register_t::kernel_start address
    std::ifstream kernel_file(file_name);
    int i = static_cast<int>(address_t::kernel_start);
    while (!kernel_file.eof()) {
        std::string line;
        std::getline(kernel_file, line);
        RAM_data[i] = std::move(line);
        i++;
    }

    // Set free memory range:
    write_to_address(address_t::free_memory_start, std::to_string(i));
    write_to_address(address_t::free_memory_end, std::to_string(ram_size));

    // jump to kernel start
    jump(std::to_string(static_cast<int>(address_t::kernel_start) - 1));

    // Main execution loop
    while (true) {
        jump_next();
        if (debug_on) {
            jump_print_debug_info();
        }

        std::string next_cmd = read_from_address(address_t::program_counter);
        std::string cur_instruction = read_from_address(next_cmd);
        std::istringstream iss(cur_instruction);
        int instr_code;
        if (cur_instruction.substr(0, 8) == "DEBUG_ON") {
            debug_on = true;
            continue;
        } else if (cur_instruction.substr(0, 9) == "DEBUG_OFF") {
            debug_on = false;
            continue;
        }

        iss >> instr_code;

        switch (static_cast<cpu_instruction_t>(instr_code)) {
            case cpu_instruction_t::cpu_exec:
                cpu_exec();
                break;
            case cpu_instruction_t::copy_from_to_address:
                {
                    std::string src, dest;
                    if (!(iss >> src >> dest)) {
                        std::cerr << "Error: copy_from_to_address expects 2 arguments (src, dest)" << std::endl;
                        exit(1);
                    }
                    copy_from_to_address(src, dest);
                }
                break;
            case cpu_instruction_t::read_from_address:
                read_from_address(iss.str().substr(cur_instruction.find(' ') + 1));
                break;
            case cpu_instruction_t::jump:
                jump(iss.str().substr(cur_instruction.find(' ') + 1));
                break;
            case cpu_instruction_t::jump_if:
                jump_if(iss.str().substr(cur_instruction.find(' ') + 1));
                break;
            case cpu_instruction_t::jump_if_not:
                jump_if_not(iss.str().substr(cur_instruction.find(' ') + 1));
                break;
            case cpu_instruction_t::jump_err:
                jump_err(iss.str().substr(cur_instruction.find(' ') + 1));
                break;
            default:
                std::cerr << "Unknown instruction: " << cur_instruction << std::endl;
                exit(1);
        }

        if (debug_on) {
            dump_RAM_to_file();
            // std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }
    return 0;
}
