model mohinh1ST

global control: reflex {
	file cell_file <- grid_file("../includes/2005x400.tif");
	list<cell_dat> active_cell <- cell_dat where (each.grid_value != 0);
	float tong_luc;
	float tong_luk;
	float tong_tsl;
	float tong_lnq;
	float tong_ont;
	file song_file <- '../includes/htsong2005.shp';
	file duong_file <- '../includes/htgiaothong2005.shp';
	float w_lancan <- 0.8;
	file landsuitability_file <- csv_file('../includes/landsuitability.csv');
	matrix matran_thichnghi;
	geometry shape <- envelope(cell_file);
	file cell_hieuchinh_file <- grid_file("../includes/2010x400.tif");
	list<cell_hieuchinh> active_cell_hieuchinh <- cell_hieuchinh where (each.grid_value != 0);
	float v_kappa <- 0.0;
	float w_lancan_TSL <- 1.0;
	float w_lancan_LUK <- 1.0;

	action tinhtongdt {
		tong_luc <- 0;
		tong_tsl <- 0;
		tong_ont <- 0;
		tong_luk <- 0;
		tong_lnq <- 0;
		ask active_cell {
			if (landuse = 5) {
				tong_luc <- tong_luc + 50 * 50;
			}

			if (landuse = 34) {
				tong_tsl <- tong_tsl + 50 * 50;
			}

			if (landuse = 41) {
				tong_ont <- tong_ont + 50 * 50;
			}

			if (landuse = 6) {
				tong_luk <- tong_luk + 50 * 50;
			}

			if (landuse = 14) {
				tong_lnq <- tong_lnq + 50 * 50;
			}

		}

		write "Tong dt lua: " + tong_luc;
		write "Tong dt ts: " + tong_tsl;
		write "Tong dt nong thon: " + tong_ont;
		write "Tong dt lua khac: " + tong_luk;
		write "Tong dt cay an qua: " + tong_lnq;
	}

	action doc_matran_TN {
		matran_thichnghi <- matrix(landsuitability_file);
		write "Ma tran Thich Nghi" + matran_thichnghi;
	}

	action tinh_kappa {
		list<int> categories <- [0];
		ask active_cell {
			if not (landuse in categories) {
				categories << landuse;
			}

		}

		ask active_cell_hieuchinh {
			if not (landuse in categories) {
				categories << landuse;
			}

		}

		write "In kiem tra categories: " + categories;
		v_kappa <- kappa(cell_hieuchinh collect (each.landuse), cell_dat collect (each.landuse), categories);
		write "Kappa: " + v_kappa;
	}

	action gan_landuse_hc {
		ask cell_dat {
			landuse_hc <- cell_hieuchinh[self.grid_x, self.grid_y].landuse;
		}

	}

	reflex main_reflex {
		ask active_cell {
			do tinh_chiso_lancan;
			do tinh_hesochuyendoi;
		}

		list<cell_dat> cell_chuyendoiTSL <- active_cell where (each.hesochuyendoi_tsl > 0.3 and each.landuse != 34);
		ask cell_chuyendoiTSL {
			int dvdd <- 11;
			if xet_thichnghi(dvdd, 34) <= 34 {
				if flip(0.9) {
					landuse <- 34;
					do to_mau;
				}

			}

		}

		list<cell_dat> cell_chuyendoiLUK <- active_cell where (each.hesochuyendoi_luk > 0.3 and each.landuse != 6);
		ask cell_chuyendoiLUK {
			int dvdd <- 11;
			if xet_thichnghi(dvdd, 6) <= 6 {
				if flip(0.9) {
					landuse <- 6;
					do to_mau;
				}

			}

		}

		do tinhtongdt;
		if (cycle = 5) {
			do tinh_kappa;
			//do pause;
		}

	}

	init {
		do doc_matran_TN;
		create song from: song_file;
		create duong from: duong_file;
		ask active_cell {
			do to_mau;
		}

		ask active_cell_hieuchinh {
			do to_mau_hc;
		}

		do gan_landuse_hc;
	}

}

grid cell_dat file: cell_file control: reflex neighbors: 8 {
	int landuse <- int(grid_value);
	rgb color;
	float hesochuyendoi_tsl;
	float hesochuyendoi_luk;
	float chiso_TSL_lancan;
	float chiso_LUK_lancan;
	int landuse_hc <- int(grid_value);

	init {
	}

	action to_mau {
		if (landuse = 5) {
			color <- rgb(255, 252, 140);
		}

		if (landuse = 34) {
			color <- rgb(170, 255, 255);
		}

		if (landuse = 6) {
			color <- rgb(255, 252, 150);
		}

		if (landuse = 14) {
			color <- rgb(255, 210, 160);
		}

		if (landuse = 41) {
			color <- rgb(255, 208, 255);
		}

	}

	action tinh_hesochuyendoi {
		hesochuyendoi_tsl <- w_lancan_TSL * chiso_TSL_lancan;
		hesochuyendoi_luk <- w_lancan_LUK * chiso_LUK_lancan;
	}

	action tinh_chiso_lancan {
		list<cell_dat> cell_lancan <- (self neighbors_at 1);
		chiso_TSL_lancan <- (cell_lancan count (each.landuse = 34)) / 8;
		chiso_LUK_lancan <- (cell_lancan count (each.landuse = 6)) / 8;
	}

	int xet_thichnghi (int madvdd, int LUT) {
		int kqthichnghi <- 0;
		int i <- 0;
		int j <- 0;
		loop i from: 1 to: matran_thichnghi.rows - 1 {
			if (matran_thichnghi[0, i] = madvdd) {
				loop j from: 1 to: matran_thichnghi.columns - 1 {
					if (matran_thichnghi[j, 0] = LUT) {
						kqthichnghi <- int(matran_thichnghi[j, i]);
					}

				}

			}

		}

		return kqthichnghi;
	}

}

species song control: reflex {
	int id;
		rgb color <- rgb(160, 255, 255);

	init {
	}

}

species duong control: reflex {
	int id;
	rgb color <- rgb(255, 170, 50);

	init {
	}

}

grid cell_hieuchinh file: cell_hieuchinh_file control: reflex neighbors: 8 {
	int landuse <- int(grid_value);
	rgb color;

	init {
	}

	action to_mau_hc {
		if (landuse = 5) {
			color <- rgb(255, 252, 140);
		}

		if (landuse = 34) {
			color <- rgb(170, 255, 255);
		}

		if (landuse = 6) {
			color <- rgb(255, 252, 150);
		}

		if (landuse = 14) {
			color <- rgb(255, 210, 160);
		}

		if (landuse = 41) {
			color <- rgb(255, 208, 255);
		}

	}

}

experiment "my_GUI_xp" type: gui {
	parameter "Trong so Lan can" var: w_lancan <- 0.8;
	output {
		display mophong type: java2D {
			grid cell_dat;
			species song;
			species duong;
		}

		display bieudo type: java2D {
			chart "Layer" type: series background: rgb(255, 255, 255) {
				data "Tong dt lua" style: line value: tong_luc color: rgb(255, 252, 140);
				data "Tong dt tsl" style: line value: tong_tsl color: rgb(170, 255, 255);
				data "Tong dt luk" style: line value: tong_luk color: rgb(255, 252, 150);
				data "Tong dt ont" style: line value: tong_ont color: rgb(255, 208, 255);
				data "Tong dt lnq" style: line value: tong_lnq color: rgb(255, 210, 160);
			}

		}

		display bando_hieuchinh type: java2D {
			grid cell_hieuchinh;
			species song;
		}

		display kiemtra type: opengl {
			grid cell_dat;
			grid cell_hieuchinh;
		}

	}

}

experiment "Can_chinh" type: batch repeat: 1 keep_seed: true until: ( time > 5 ){
	parameter 'Trong so lan can TSL:' var: w_lancan_TSL min: 0.1 max: 1.0 step:0.1;
	parameter 'Trong so lan can LUK:' var: w_lancan_LUK min: 0.1 max: 1.0 step:0.1;
	method exhaustive maximize: v_kappa;
}