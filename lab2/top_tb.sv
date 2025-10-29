`timescale 1ns/1ps
`include "apb_interface.sv"
`include "apb_master.sv"
`include "apb_slave.sv"

module tb_apb();
    logic clk, reset;
    apb_interface apb_if();

    initial begin
        clk = 0;
        reset = 0;
        #20 reset = 1;
        forever #5 clk = ~clk;
    end

    assign apb_if.PCLK = clk;
    assign apb_if.PRESETn = reset;

    apb_slave slave (apb_if.slave_mp);
    apb_master master (apb_if.master_mp);
    
    initial begin
        // Ждем сброса
        wait(reset === 1'b1);
        $display("Reset released, starting tests...");
        
        // Небольшая задержка после сброса
        repeat(2) @(posedge clk);

        $display("\n=====[TEST 1] Initial values and register setup=====");
        master.read('h0); // add_value
        master.read('h4); // mask
        master.read('h8); // control
        master.read('hC); // result

        $display("\n=====[TEST 2] Set initial values and mask=====");
        master.write('h0, 32'h0000000F); // add_value = 15
        master.write('h4, 32'h0000000F); // mask = 15 (0x0F)
        master.write('h8, 32'd3); // control = 3 (set initial result)
        master.read('hC); // Read result

        $display("\n=====[TEST 3] First accumulation operation=====");
        master.write('h0, 32'h00000003); // add_value = 3
        master.write('h8, 32'd1); // control = 1 (execute operation)
        master.read('hC); // Read result

        $display("\n=====[TEST 4] Second accumulation operation=====");
        master.write('h0, 32'h00000007); // add_value = 7
        master.write('h8, 32'd1); // control = 1 (execute operation)
        master.read('hC); // Read result

        $display("\n=====[TEST 5] Change mask and accumulate=====");
        master.write('h4, 32'h00000003); // mask = 3 (0x03)
        master.write('h0, 32'h0000000F); // add_value = 15
        master.write('h8, 32'd1); // control = 1 (execute operation)
        master.read('hC); // Read result

        $display("\n=====[TEST 6] Reset operation=====");
        master.write('h8, 32'd2); // control = 2 (reset result)
        master.read('hC); // Read result (should be 0)

        $display("\n=====[TEST 7] New sequence with different mask=====");
        master.write('h4, 32'h000000FF); // mask = 255
        master.write('h0, 32'h00000012); // add_value = 18
        master.write('h8, 32'd3); // control = 3 (set initial result)
        master.read('hC);

        master.write('h0, 32'h00000034); // add_value = 52
        master.write('h8, 32'd1); // control = 1 (execute operation)
        master.read('hC);

        $display("\n=====[TEST 8] Additional coverage tests for high bits=====");
        // Тестирование старших битов
        master.write('h0, 32'hFFFF0000); // add_value с старшими битами
        master.write('h4, 32'h00FF00FF); // mask с разными паттернами
        master.write('h8, 32'd3); // control = 3 (set initial result)
        master.read('hC);

        master.write('h0, 32'h12345678); // другое значение
        master.write('h8, 32'd1); // control = 1 (execute operation)
        master.read('hC);

        $display("\n=====[TEST 9] Edge cases and boundary values=====");
        // Граничные значения
        master.write('h0, 32'h00000000); // нулевое значение
        master.write('h4, 32'h00000000); // нулевая маска
        master.write('h8, 32'd1); // операция с нулями
        master.read('hC);

        master.write('h0, 32'hFFFFFFFF); // все единицы
        master.write('h4, 32'hFFFFFFFF); // маска все единицы
        master.write('h8, 32'd1); // операция
        master.read('hC);

        master.write('h0, 32'hAAAAAAAA); // паттерн
        master.write('h4, 32'h55555555); // инверсный паттерн
        master.write('h8, 32'd1); // операция
        master.read('hC);

        $display("\n=====[TEST 10] Multiple operations sequence=====");
        // Последовательность операций
        master.write('h8, 32'd2); // сброс
        master.write('h4, 32'h0000000F); // маска
        master.write('h0, 32'h00000001); 
        master.write('h8, 32'd1); // операция 1
        master.write('h0, 32'h00000002); 
        master.write('h8, 32'd1); // операция 2
        master.write('h0, 32'h00000004); 
        master.write('h8, 32'd1); // операция 3
        master.write('h0, 32'h00000008); 
        master.write('h8, 32'd1); // операция 4
        master.read('hC);

        $display("\n=====[TEST 11] Control register edge cases=====");
        // Тестирование граничных значений control_reg
        master.write('h8, 32'd0); // control = 0 (no operation)
        master.read('h8);
        master.write('h8, 32'd1); // control = 1
        master.read('h8);
        master.write('h8, 32'd2); // control = 2
        master.read('h8);
        master.write('h8, 32'd3); // control = 3
        master.read('h8);

        $display("\n=====[TEST 12] Attempt to write read-only register=====");
        master.write('hC, 32'hDEAD_BEEF); // Try to write result register

        $display("\n=====[TEST 13] Invalid address check=====");
        master.write('hFFFFFFFF, 32'h12345678);
        master.read('h10000000);

        // Дополнительные неверные адреса
        master.write('h10, 32'h11111111);
        master.read('h14);

        $display("\n=====[TEST 14] Mixed read/write operations=====");
        // Чередование чтения и записи
        master.write('h0, 32'h11111111);
        master.read('h0);
        master.write('h4, 32'h22222222);
        master.read('h4);
        master.write('h8, 32'd3);
        master.read('h8);
        master.read('hC);

        $display("\n=====[TEST 15] Reset behavior after activity=====");
        reset = 0; #10; reset = 1;
        master.read('h0);
        master.read('h4);
        master.read('h8);
        master.read('hC);

        $display("\n=====[TEST 16] Post-reset operations=====");
        // Операции после сброса
        master.write('h0, 32'h00000042);
        master.write('h4, 32'h000000FF);
        master.write('h8, 32'd3);
        master.read('hC);
        master.write('h8, 32'd1);
        master.read('hC);

        $display("\n====[TEST COMPLETED SUCCESSFULLY]====\n");
        #50;
        $finish;
    end

endmodule