`timescale 1ns/1ps

module apb_slave (
    // APB интерфейс
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR
);

    // Внутренние регистры согласно варианту 11
    logic [31:0] add_value_reg;    // Добавляемое значение
    logic [31:0] control_reg;      // Контрольный регистр
    logic [31:0] result_reg;       // Текущий результат (накопление)
    
    // Биты контрольного регистра
    logic enable_operation;        // Бит 0: разрешение операции
    logic clear_result;            // Бит 1: сброс результата
    logic operation_done;          // Бит 2: операция завершена
    
    // Временные сигналы
    logic [31:0] temp_result;
    logic operation_trigger;       // Триггер для выполнения операции
    logic clear_trigger;           // Триггер для сброса результата
    
    // Всегда готовы
    assign PREADY = 1'b1;
    assign PSLVERR = 1'b0;
    
    // Декодирование битов контрольного регистра
    assign enable_operation = control_reg[0];
    assign clear_result = control_reg[1];
    assign operation_done = control_reg[2];

    // Логика операции "Сложение по И с накоплением"
    always_comb begin
        temp_result = result_reg;
        if (enable_operation && !operation_done) begin
            temp_result = result_reg + (add_value_reg & result_reg);
        end
    end

    // Триггер для выполнения операции (срабатывает по записи в control_reg)
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            operation_trigger <= 1'b0;
            clear_trigger <= 1'b0;
        end else begin
            // Триггер для операции
            if (PSEL && PENABLE && PWRITE && PADDR[3:0] == 4'h4) begin
                operation_trigger <= (PWDATA[0] && !control_reg[0]); // Триггер при установке enable
                clear_trigger <= (PWDATA[1] && !control_reg[1]);     // Триггер при установке clear
            end else begin
                operation_trigger <= 1'b0;
                clear_trigger <= 1'b0;
            end
        end
    end

    // Основная логика регистров
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            // Сброс регистров
            add_value_reg <= 32'd0;
            control_reg <= 32'd0;
            result_reg <= 32'd0;
            
            $display("");
            $display("================================================");
            $display("APB SLAVE: RESET COMPLETED");
            $display("All registers initialized to 0x00000000");
            $display("================================================");
            $display("");
        end else begin
            // Обработка сброса результата - имеет высший приоритет
            if (clear_trigger) begin
                result_reg <= 32'd0;
                control_reg[2] <= 1'b0; // Сбрасываем флаг завершения
                control_reg[1] <= 1'b0; // Сбрасываем бит clear
                $display("APB SLAVE: Result register cleared to 0x00000000");
            end 
            // Выполнение операции по триггеру
            else if (operation_trigger && enable_operation && !operation_done) begin
                result_reg <= temp_result;
                control_reg[2] <= 1'b1; // Устанавливаем флаг завершения
                control_reg[0] <= 1'b0; // Сбрасываем бит enable после операции
                $display("APB SLAVE: Operation calculation: 0x%08h + (0x%08h & 0x%08h) = 0x%08h", 
                         result_reg, add_value_reg, result_reg, temp_result);
                $display("APB SLAVE: Operation completed. New result: 0x%08h", temp_result);
            end
            
            // Запись из APB шины (имеет низший приоритет)
            if (PSEL && PENABLE && PWRITE) begin
                case (PADDR[3:0])
                    4'h0: begin
                        add_value_reg <= PWDATA;
                        $display("APB SLAVE: Add Value Register = 0x%08h", PWDATA);
                    end
                    4'h4: begin
                        // Сохраняем только биты enable и clear, остальные защищаем
                        control_reg[0] <= PWDATA[0]; // enable
                        control_reg[1] <= PWDATA[1]; // clear
                        // Бит done защищен от записи извне
                        $display("APB SLAVE: Control Register = 0x%08h", control_reg);
                    end
                    4'h8: begin
                        result_reg <= PWDATA;
                        control_reg[2] <= 1'b0; // Сброс флага завершения при ручной записи
                        $display("APB SLAVE: Result Register manually set to 0x%08h", PWDATA);
                    end
                    default: begin
                        $display("APB SLAVE: Invalid write address 0x%08h", PADDR);
                    end
                endcase
            end
        end
    end

    // Логика чтения - комбинационная логика для немедленного ответа
    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:0])
                4'h0: PRDATA = add_value_reg;
                4'h4: PRDATA = control_reg;
                4'h8: PRDATA = result_reg;
                default: PRDATA = 32'hDEADBEEF;
            endcase
            
            if (PADDR[3:0] <= 4'h8) begin
                $display("");
                $display("------------------------------------------------");
                $display("APB SLAVE: READ OPERATION");
                $display("------------------------------------------------");
                $display("Reading address 0x%08h", PADDR);
                $display("Data read: 0x%08h", PRDATA);
                $display("------------------------------------------------");
                $display("");
            end else begin
                $display("APB SLAVE: Invalid read address 0x%08h, returning 0xDEADBEEF", PADDR);
            end
        end
    end

    // Функция для отладки - печать всех регистров
    function void print_all_registers();
        begin
            $display("");
            $display("================================================");
            $display("APB SLAVE: REGISTER DUMP");
            $display("================================================");
            $display("Add Value Register (0x0): 0x%08h", add_value_reg);
            $display("Control Register   (0x4): 0x%08h", control_reg);
            $display("Result Register    (0x8): 0x%08h", result_reg);
            $display("Control bits: Enable=%b, Clear=%b, Done=%b", 
                     enable_operation, clear_result, operation_done);
            $display("================================================");
            $display("");
        end
    endfunction

endmodule