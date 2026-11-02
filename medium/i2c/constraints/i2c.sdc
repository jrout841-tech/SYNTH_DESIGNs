# Starting constraints for a block-level place-and-route experiment.
# Time unit: ns. These periods are starting points, not measured closure targets.
# Top: i2c

create_clock -name clk_i -period 10.0 [get_ports clk_i]
set_clock_uncertainty 0.150 [get_clocks clk_i]
set_clock_transition 0.100 [get_clocks clk_i]

# Asynchronous active-low resets. Do not time the reset tree as data.
set_false_path -from [get_ports {rst_ni}]

# I/O budget: 40% of the primary clock. Replace with the real SoC budget.
set_input_delay -clock clk_i -max 4.00 [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
set_output_delay -clock clk_i -max 4.00 [all_outputs]

# Drive and load are placeholders so a first timing run is not ideal-net only.
set_load 0.050 [all_outputs]
# Uncomment after naming a buffer from your standard-cell library.
# set_driving_cell -lib_cell BUF_X4 -pin Y [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
# Example: set_driving_cell -lib_cell BUF_X4 -pin Y [get_ports ...]
