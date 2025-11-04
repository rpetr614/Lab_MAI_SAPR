module apb_slave(apb_interface apb_if);

    logic [31:0] add_value_reg;    // Добавляемое значение
    logic [1:0]  control_reg;      // Контрольный регистр
    logic [31:0] result_reg;       // Текущий результат (накопленная сумма)
    logic [31:0] mask_reg;         // Регистр маски для операции И
    
    logic trans_done;
    logic ready_set;

    always_ff @(posedge apb_if.PCLK or negedge apb_if.PRESETn) begin
        if (!apb_if.PRESETn) begin
            apb_if.PREADY  <= 1'b0;
            apb_if.PSLVERR <= 1'b0;
            add_value_reg  <= 32'b0;
            control_reg    <= 2'b0;
            result_reg     <= 32'b0;
            mask_reg       <= 32'hFFFFFFFF; // Начальная маска - все единицы
            apb_if.PRDATA  <= 32'b0;
            trans_done     <= 1'b0;
            ready_set      <= 1'b0;
        end else begin
            // Сброс сигналов ошибки и готовности только когда транзакция завершена
            if (apb_if.PREADY && apb_if.PSEL && apb_if.PENABLE) begin
                apb_if.PREADY <= 1'b0;
                apb_if.PSLVERR <= 1'b0;
                ready_set <= 1'b0;
            end

            // WRITE операция
            if (apb_if.PSEL && apb_if.PENABLE && apb_if.PWRITE && !ready_set) begin
                case (apb_if.PADDR)
                    32'h0: begin // Запись добавляемого значения
                        add_value_reg <= apb_if.PWDATA;
                        $display("[APB_SLAVE] Write add_value: %0d (0x%08h)", apb_if.PWDATA, apb_if.PWDATA);
                        apb_if.PREADY <= 1'b1;
                        ready_set <= 1'b1;
                    end
                    32'h4: begin // Запись маски
                        mask_reg <= apb_if.PWDATA;
                        $display("[APB_SLAVE] Write mask: %0d (0x%08h)", apb_if.PWDATA, apb_if.PWDATA);
                        apb_if.PREADY <= 1'b1;
                        ready_set <= 1'b1;
                    end
                    32'h8: begin // Запись контрольного регистра
                        control_reg <= apb_if.PWDATA[1:0];
                        $display("[APB_SLAVE] Write control: 0x%0h", apb_if.PWDATA[1:0]);
                        
                        // Выполнение операции на основе control_reg
                        if (apb_if.PWDATA[1:0] == 2'b01) begin
                            // Операция сложения по И с накоплением: result = result + (add_value & mask)
                            result_reg <= result_reg + (add_value_reg & mask_reg);
                            $display("[APB_SLAVE] Operation: result = %0d + (%0d & %0d) = %0d", 
                                     result_reg, add_value_reg, mask_reg, 
                                     result_reg + (add_value_reg & mask_reg));
                        end else if (apb_if.PWDATA[1:0] == 2'b10) begin
                            // Сброс результата
                            result_reg <= 32'b0;
                            $display("[APB_SLAVE] Result register cleared");
                        end else if (apb_if.PWDATA[1:0] == 2'b11) begin
                            // Установка начального значения
                            result_reg <= add_value_reg;
                            $display("[APB_SLAVE] Set initial result: %0d", add_value_reg);
                        end
                        apb_if.PREADY <= 1'b1;
                        ready_set <= 1'b1;
                    end
                    32'hC: begin // Ошибка: попытка записи в регистр результата
                        $display("[APB_SLAVE] ERROR: WRITE to read-only result register (0x%08h)", apb_if.PADDR);
                        apb_if.PSLVERR <= 1'b1;
                        apb_if.PREADY  <= 1'b1;
                        ready_set <= 1'b1;
                    end 
                    default: begin // Неверный адрес
                        $display("[APB_SLAVE] ERROR: addr isn't in range (0x%08h)", apb_if.PADDR);
                        apb_if.PSLVERR <= 1'b1;
                        apb_if.PREADY  <= 1'b1;
                        ready_set <= 1'b1;
                    end
                endcase
                trans_done <= 1'b1;
            end 
            // READ операция
            else if (apb_if.PSEL && apb_if.PENABLE && !apb_if.PWRITE && !ready_set) begin
                case (apb_if.PADDR)
                    32'h0: begin // Чтение добавляемого значения
                        apb_if.PRDATA <= add_value_reg;
                        $display("[APB_SLAVE] Read add_value: %0d (0x%08h)", add_value_reg, add_value_reg);
                    end
                    32'h4: begin // Чтение маски
                        apb_if.PRDATA <= mask_reg;
                        $display("[APB_SLAVE] Read mask: %0d (0x%08h)", mask_reg, mask_reg);
                    end
                    32'h8: begin // Чтение контрольного регистра
                        apb_if.PRDATA <= {30'd0, control_reg};
                        $display("[APB_SLAVE] Read control: 0x%0h", control_reg);
                    end
                    32'hC: begin // Чтение текущего результата
                        apb_if.PRDATA <= result_reg;
                        $display("[APB_SLAVE] Read result: %0d (0x%08h)", result_reg, result_reg);
                    end
                    default: begin // Неверный адрес
                        $display("[APB_SLAVE] ERROR: addr isn't in range (0x%08h)", apb_if.PADDR);
                        apb_if.PSLVERR <= 1'b1;
                        apb_if.PRDATA  <= 32'hDEAD_BEEF;
                    end
                endcase
                apb_if.PREADY <= 1'b1;
                ready_set <= 1'b1;
                trans_done <= 1'b1;
            end

        end // else not reset
    end // always_ff

endmodule