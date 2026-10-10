reset_runs synth_1;
launch_runs synth_1 -jobs 8;
launch_runs impl_1;
wait_on_runs impl_1;
launch_runs impl_1 -to_step write_bitstream -jobs 8;
