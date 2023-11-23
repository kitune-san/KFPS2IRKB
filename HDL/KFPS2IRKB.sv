//
// KFPS2IRKB
// 
//
// Written by kitune-san
//
module KFPS2IRKB #(
    parameter over_time         = 16'd1000,
    parameter bit_phase_cycle   = 16'd22000-16'd1   // 440us @ 50MHz
) (
    input   logic           clock,
    input   logic           reset,

    input   logic           device_clock,
    input   logic           device_data,

    output  logic           ir_signal
);

    //
    // Internal signals
    //
    logic           irq;
    logic   [7:0]   keycode;
    logic           clear_keycode;
    logic   [9:0]   shift_register;
    logic           shift;
    logic   [3:0]   send_count;
    logic           sending;
    logic   [1:0]   send_code;
    logic   [15:0]  phase_cycle_count;
    logic           bit_1_signal;
    logic           bit_0_signal;


    //
    // PS/2 Keyboard
    //
    KFPS2KB #(
        .over_time          (over_time)
    ) u_KFPS2KB (
        .clock              (clock),
        .reset              (reset),
        .device_clock       (device_clock),
        .device_data        (device_data),
        .irq                (irq),
        .keycode            (keycode),
        .clear_keycode      (clear_keycode)
    );


    //
    // Shift Register
    //
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            shift_register      <= 10'b1111111111;
        else if (shift)
            shift_register      <= {1'b1, shift_register[9:1]};
        else if (~sending & irq)
            shift_register      <= {1'b1, keycode, 1'b1};
        else
            shift_register      <= shift_register;
    end


    //
    // Send IR Signal
    //
    // Control send data(shift register)
    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            send_count          <= 4'd0;
            shift               <= 1'b0;
            clear_keycode       <= 1'b0;
        end
        else if (~|phase_cycle_count) begin
            if (|send_count) begin
                send_count      <= send_count - 4'd1;
                clear_keycode   <= 1'b0;
                shift           <= 1'b1;
            end
            else if (irq) begin
                send_count      <= 4'd10;
                clear_keycode   <= 1'b1;
                shift           <= 1'b0;
            end
            else begin
                send_count      <= send_count;
                clear_keycode   <= 1'b0;
                shift           <= 1'b0;
            end
        end
        else begin
            send_count          <= send_count;
            shift               <= 1'b0;
            clear_keycode       <= 1'b0;
        end
    end

    assign  sending     = |send_count;
    assign  send_code   = {sending, shift_register[0]};

    // Generate phase cycle
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            phase_cycle_count   <= bit_phase_cycle;
        else if (~|phase_cycle_count)
            phase_cycle_count   <= bit_phase_cycle;
        else
            phase_cycle_count   <= phase_cycle_count - 1'd1;
    end

    // Generate 1
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            bit_1_signal        <= 1'b1;
        else if (phase_cycle_count == bit_phase_cycle)
            bit_1_signal        <= 1'b0;
        else if (phase_cycle_count == {1'b0, bit_phase_cycle[15:1]})
            bit_1_signal        <= 1'b1;
        else
            bit_1_signal        <= bit_1_signal;
    end

    // Generate 0
    assign  bit_0_signal = ~bit_1_signal;


    //
    // Output ir_signal
    //
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            ir_signal           <= 1'b1;
        else
            casez (send_code)
                2'b10:  ir_signal   <= bit_0_signal;
                2'b11:  ir_signal   <= bit_1_signal;
                default:ir_signal   <= 1'b1;
            endcase
    end

endmodule

