`timescale 1ns/1ps

module Testbench;

    // Тактовый сигнал и сброс
    logic clk;
    logic rst_n;
    
    // APB сигналы
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PADDR;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;
    
    // Переменные для покрытия
    logic [31:0] coverage_bins [string];
    int statement_count = 0;
    int branch_count = 0;
    int condition_count = 0;
    int fsm_state_count = 0;
    int toggle_count = 0;
    int function_count = 0;
    
    // Переменные для мониторинга переключений
    logic prev_PSEL = 0;
    logic prev_PENABLE = 0;
    logic prev_PWRITE = 0;
    logic [31:0] prev_PADDR = 0;
    logic [31:0] prev_PWDATA = 0;
    logic [31:0] prev_PRDATA = 0;
    
    // Генерация тактового сигнала
    initial begin
        clk = 0;
        $display("Starting clock generation...");
        forever #5 clk = ~clk;
    end
    
    // Генерация сброса
    initial begin
        rst_n = 0;
        $display("Reset asserted");
        #20 rst_n = 1;
        $display("Reset deasserted at time %0t", $time);
    end
    
    // Инстанциирование мастера
    apb_master master_inst (
        .PCLK(clk),
        .PRESETn(rst_n),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );
    
    // Инстанциирование slave
    apb_slave slave_inst (
        .PCLK(clk),
        .PRESETn(rst_n),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );
    
    // Мониторинг покрытия операторов
    function void cover_statement(string statement_name);
        statement_count++;
        coverage_bins[statement_name] = 1;
        $display("COVERAGE: Statement executed - %s (Total: %0d)", statement_name, statement_count);
    endfunction
    
    // Мониторинг покрытия условий
    function void cover_condition(string condition_name, logic condition);
        condition_count++;
        $display("COVERAGE: Condition evaluated - %s = %b (Total: %0d)", 
                 condition_name, condition, condition_count);
    endfunction
    
    // Мониторинг покрытия ветвлений
    function void cover_branch(string branch_name);
        branch_count++;
        $display("COVERAGE: Branch taken - %s (Total: %0d)", branch_name, branch_count);
    endfunction
    
    // Мониторинг переключений битов
    function void cover_toggle(string signal_name, logic prev_val, logic curr_val);
        if (prev_val !== curr_val && prev_val !== 1'bx && curr_val !== 1'bx) begin
            toggle_count++;
            $display("COVERAGE: Toggle detected - %s: %b -> %b (Total: %0d)", 
                     signal_name, prev_val, curr_val, toggle_count);
        end
    endfunction
    
    // Мониторинг переключений шин
    function void cover_bus_toggle(string signal_name, logic [31:0] prev_val, logic [31:0] curr_val);
        if (prev_val !== curr_val) begin
            toggle_count++;
            $display("COVERAGE: Bus toggle detected - %s: 0x%08h -> 0x%08h (Total: %0d)", 
                     signal_name, prev_val, curr_val, toggle_count);
        end
    endfunction
    
    // Мониторинг FSM состояний
    function void cover_fsm_state(string state_name);
        fsm_state_count++;
        $display("COVERAGE: FSM state - %s (Total: %0d)", state_name, fsm_state_count);
    endfunction
    
    // Мониторинг вызовов функций
    function void cover_function_call(string func_name);
        function_count++;
        $display("COVERAGE: Function called - %s (Total: %0d)", func_name, function_count);
    endfunction
    
    // Основной тест с расширенным покрытием
    initial begin
        logic [31:0] read_data;
        
        // Инициализация покрытия
        coverage_bins["reset_test"] = 0;
        coverage_bins["write_operations"] = 0;
        coverage_bins["read_operations"] = 0;
        coverage_bins["accumulation_operation"] = 0;
        coverage_bins["control_flags"] = 0;
        coverage_bins["boundary_cases"] = 0;
        coverage_bins["error_cases"] = 0;
        coverage_bins["operation_success"] = 0;
        coverage_bins["clear_success"] = 0;
        
        // Инициализация
        #30;
        cover_statement("test_initialization");
        $display("");
        $display("************************************************");
        $display("APB ACCUMULATOR TEST WITH COVERAGE STARTED");
        $display("************************************************");
        $display("");
        
        // Тест 1: Сброс и инициализация
        $display("TEST 1: Reset and initialization coverage");
        cover_branch("reset_completion");
        coverage_bins["reset_test"] = 1;
        
        master_inst.apb_write(32'h00000000, 32'h0000000F); // Add value = 0xF
        cover_statement("write_add_value");
        coverage_bins["write_operations"] = 1;
        #40;
        
        master_inst.apb_write(32'h00000008, 32'h00000003); // Initial result = 0x3
        cover_statement("write_initial_result");
        #40;
        
        // Тест 2: Операция накопления
        $display("TEST 2: Accumulation operation coverage");
        cover_function_call("accumulation_operation");
        coverage_bins["accumulation_operation"] = 1;
        
        $display("Operation: result = result + (add_value & result)");
        $display("Initial: result=0x3, add_value=0xF");
        $display("Expected: 0x3 + (0xF & 0x3) = 0x3 + 0x3 = 0x6");
        
        master_inst.apb_write(32'h00000004, 32'h00000001); // Enable operation
        cover_statement("enable_operation");
        cover_condition("enable_bit_set", 1'b1);
        #60; // Даем время на выполнение операции
        
        // Проверка результата
        master_inst.apb_read(32'h00000008, read_data);
        cover_statement("read_result_after_operation");
        coverage_bins["read_operations"] = 1;
        cover_condition("result_correct", read_data == 32'h00000006);
        
        $display("Result after operation: 0x%08h (Expected: 0x00000006)", read_data);
        if (read_data == 32'h00000006) begin
            cover_branch("operation_success");
            coverage_bins["operation_success"] = 1;
            $display("PASS: Operation result correct!");
        end else begin
            cover_branch("operation_failure");
            $display("FAIL: Operation result incorrect!");
        end
        #20;
        
        // Тест 3: Проверка флагов управления
        $display("TEST 3: Control flags coverage");
        coverage_bins["control_flags"] = 1;
        
        master_inst.apb_read(32'h00000004, read_data);
        cover_statement("read_control_register");
        $display("Control register after operation: 0x%08h", read_data);
        
        cover_condition("operation_done_flag", read_data[2] == 1'b1);
        if (read_data[2] == 1'b1) begin
            cover_branch("flag_set_correctly");
            $display("PASS: Operation done flag set correctly!");
        end else begin
            cover_branch("flag_not_set");
            $display("FAIL: Operation done flag not set!");
        end
        #20;
        
        // Тест 4: Сброс результата
        $display("TEST 4: Result clear coverage");
        master_inst.apb_write(32'h00000004, 32'h00000002); // Set clear bit
        cover_statement("set_clear_bit");
        cover_condition("clear_bit_set", 1'b1);
        #60; // Даем время на сброс
        
        master_inst.apb_write(32'h00000004, 32'h00000000); // Clear control reg
        cover_statement("clear_control_reg");
        #20;
        
        master_inst.apb_read(32'h00000008, read_data);
        cover_statement("read_after_clear");
        cover_condition("result_cleared", read_data == 32'h00000000);
        
        if (read_data == 32'h00000000) begin
            cover_branch("clear_success");
            coverage_bins["clear_success"] = 1;
            $display("PASS: Result register cleared!");
        end else begin
            cover_branch("clear_failure");
            $display("FAIL: Result register not cleared!");
        end
        #20;
        
        // Тест 5: Граничные случаи
        $display("TEST 5: Boundary cases coverage");
        coverage_bins["boundary_cases"] = 1;
        
        // Максимальные значения
        cover_statement("test_max_values");
        master_inst.apb_write(32'h00000000, 32'hFFFFFFFF);
        master_inst.apb_write(32'h00000008, 32'hFFFFFFFF);
        #40;
        master_inst.apb_write(32'h00000004, 32'h00000001);
        #60;
        master_inst.apb_read(32'h00000008, read_data);
        $display("Max values result: 0x%08h (Expected: 0xFFFFFFFE)", read_data);
        if (read_data == 32'hFFFFFFFE) 
            $display("PASS: Max values operation correct!");
        else 
            $display("FAIL: Max values operation incorrect!");
        
        // Нулевые значения
        cover_statement("test_zero_values");
        master_inst.apb_write(32'h00000000, 32'h00000000);
        master_inst.apb_write(32'h00000008, 32'h00000001);
        #40;
        master_inst.apb_write(32'h00000004, 32'h00000001);
        #60;
        master_inst.apb_read(32'h00000008, read_data);
        $display("Zero add value result: 0x%08h (Expected: 0x00000001)", read_data);
        if (read_data == 32'h00000001) 
            $display("PASS: Zero values operation correct!");
        else 
            $display("FAIL: Zero values operation incorrect!");
        
        // Тест 6: Ошибочные случаи
        $display("TEST 6: Error cases coverage");
        coverage_bins["error_cases"] = 1;
        
        // Чтение несуществующего адреса
        cover_statement("test_invalid_address");
        master_inst.apb_read(32'h000000FF, read_data);
        cover_condition("invalid_address_handled", read_data == 32'hDEADBEEF);
        $display("Invalid address read: 0x%08h", read_data);
        if (read_data == 32'hDEADBEEF) 
            $display("PASS: Invalid address handled correctly!");
        else 
            $display("FAIL: Invalid address not handled!");
        
        // Печать всех регистров для проверки
        slave_inst.print_all_registers();
        
        // Генерация отчета о покрытии
        generate_coverage_report();
        
        // Финальный отчет
        $display("");
        $display("************************************************");
        $display("APB ACCUMULATOR TEST WITH COVERAGE COMPLETED");
        $display("************************************************");
        $display("Summary: All coverage metrics collected");
        $display("Simulation time: %0t ns", $time);
        $display("************************************************");
        $display("");
        
        #50;
        $finish;
    end
    
    // Генерация отчета о покрытии
    function void generate_coverage_report();
        automatic int covered_bins;
        automatic int total_bins;
        
        covered_bins = 0;
        total_bins = 0;
        
        $display("");
        $display("================================================");
        $display("COVERAGE REPORT");
        $display("================================================");
        $display("Statement Coverage:    %0d statements executed", statement_count);
        $display("Branch Coverage:       %0d branches taken", branch_count);
        $display("Condition Coverage:    %0d conditions evaluated", condition_count);
        $display("FSM Coverage:          %0d states visited", fsm_state_count);
        $display("Toggle Coverage:       %0d toggles detected", toggle_count);
        $display("Function Coverage:     %0d functions called", function_count);
        $display("");
        $display("Functional Coverage Bins:");
        foreach (coverage_bins[i]) begin
            $display("  %s: %s", i, coverage_bins[i] ? "COVERED" : "NOT COVERED");
            total_bins++;
            if (coverage_bins[i]) covered_bins++;
        end
        $display("");
        $display("Functional Coverage: %0d/%0d (%0.1f%%)", 
                 covered_bins, total_bins, (covered_bins * 100.0) / total_bins);
        $display("================================================");
    endfunction
    
    // Мониторинг переключений сигналов APB
    always @(posedge clk) begin
        cover_toggle("PSEL", prev_PSEL, PSEL);
        cover_toggle("PENABLE", prev_PENABLE, PENABLE);
        cover_toggle("PWRITE", prev_PWRITE, PWRITE);
        cover_bus_toggle("PADDR", prev_PADDR, PADDR);
        cover_bus_toggle("PWDATA", prev_PWDATA, PWDATA);
        cover_bus_toggle("PRDATA", prev_PRDATA, PRDATA);
        
        prev_PSEL = PSEL;
        prev_PENABLE = PENABLE;
        prev_PWRITE = PWRITE;
        prev_PADDR = PADDR;
        prev_PWDATA = PWDATA;
        prev_PRDATA = PRDATA;
    end
    
    // Мониторинг FSM состояний мастера
    always @(master_inst.state) begin
        case (master_inst.state)
            2'b00: cover_fsm_state("IDLE");
            2'b01: cover_fsm_state("SETUP");
            2'b10: cover_fsm_state("ACCESS");
            default: cover_fsm_state("UNKNOWN");
        endcase
    end
    
    // Мониторинг APB шины
    initial begin
        $monitor("Time: %0t | APB_BUS: PSEL=%b PENABLE=%b PWRITE=%b PADDR=0x%08h PWDATA=0x%08h PRDATA=0x%08h PREADY=%b", 
                 $time, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY);
    end

    // Тайм-аут для безопасности
    initial begin
        #5000; // 5000 нс тайм-аут
        $display("");
        $display("TIMEOUT: Simulation took too long, forcing finish");
        generate_coverage_report();
        $display("");
        $finish;
    end

endmodule