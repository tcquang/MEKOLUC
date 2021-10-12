/*
 * 
 * 
 */
model landuse_st_v1

global control: reflex {
	file cell_file <- grid_file("../includes/2005x400.tif");
	file river_file <- shape_file('../includes/htsong2005.shp');
	file road_file <- shape_file('../includes/htgiaothong2005.shp');
	file district_file <- shape_file('../includes/huyenST_2019_region.shp');
	
	file cell_calibrate_file <- grid_file("../includes/2010x400.tif");
	file landunit_file <- shape_file('../includes/dvdd_hientai_region.shp');
	// 3 layers of land unit map
	file soiltype_file <- shape_file('../includes/LMU/soiltype_region.shp');
	file salinity_file <- shape_file('../includes/LMU/salinity2015_region.shp');
	file salt_time_file <- shape_file('../includes/LMU/salt_time_ST_2010_region.shp');
	
	file bebefit_file <- csv_file('../includes/dataset/benefit.csv', false);
	file landsuitability_2_file <- csv_file('../includes/dataset/landsuitability.csv', false);
	file shiftable_eval_file <- csv_file('../includes/dataset/danhgia_khokhan_chuyendoi.csv', false);
	list<land_cell> active_cell <- land_cell where (each.grid_value != 0.0 and each.grid_value != 19.0 and each.grid_value != 24.0 and each.grid_value != 98.0);
	float total_rice;
	float total_riceother;
	float total_shrimp;
	float total_fruit;
	float w_lancan <- 0.8;
	matrix suitability_matrix;
	map<string, map<int,float>> suitability_map;	
	matrix bebefit_matrix;
	geometry shape <- envelope(cell_file);
	list<cell_calibrate> active_cell_calibrate <- cell_calibrate where (each.grid_value != 0);
	float v_kappa <- 0.0;
	list creteria;
	float w_suitability <- 1.0 ;
	matrix dif_shifting_matrix;
	float w_diff_shifting <- 0.8;
	float w_benefit <- 0.5;
 	bool batch_mode <-false;
	float total_crops;

	action tinhtongdt {
		total_rice <- 0.0;
		total_shrimp <- 0.0;
		total_riceother <- 0.0;
		total_fruit <- 0.0;
		total_crops <- 0.0;
		ask active_cell {
			if (landuse = 5) {
				total_rice <- total_rice + 400 * 400 / 10000;
			}

			if (landuse = 34) {
				total_shrimp <- total_shrimp + 400 * 400 / 10000;
			}

			if (landuse = 6) {
				total_riceother <- total_riceother + 400 * 400 / 10000;
			}

			if (landuse = 14) {
				total_fruit <- total_fruit + 400 * 400 / 10000;
			}

			if (landuse = 12) {
				total_crops <- total_crops + 400 * 400 / 10000;
			}

		}

		write "Tong dt lua: " + total_rice;
		write "Tong dt ts: " + total_shrimp;
		write "Tong dt lua khac: " + total_riceother;
		write "Tong dt cay an qua: " + total_fruit;
		write "Tong dt cay hang nam: " + total_crops;
	}

//	action doc_matran_TN {
//		suitability_matrix <- matrix(landsuitability_2_file);
//		write "Ma tran Thich Nghi" + suitability_matrix;
//	}	
	action build_suitability_map {		
//		write "envi  \n  "+suitability_file;																	// load the suitability map into
		string sland_unit <-"";
		matrix st_mat <- matrix(landsuitability_2_file);
		loop i from: 1 to: st_mat.rows - 1{
			sland_unit <-"";
			map<int,float> map_land_unit <- [];
			sland_unit <- ""+st_mat[0,i]+string(st_mat[1,i])+string(st_mat[2,i]);
			loop j from: 3 to: st_mat.columns -1{
				map_land_unit[int(st_mat[j,0])] <-float(st_mat[j,i]); 
			}
			suitability_map[sland_unit] <- map_land_unit;
		}
		write "Ma tran thich nghi:" +suitability_map;
	}
	action doc_matran_Loinhuan {
		bebefit_matrix <- matrix(bebefit_file);
		write "Ma tran Loi nhuan" + bebefit_matrix;
	}
	action tinh_kappa {
		list<int> categories <- [0];
		ask active_cell {
			if not (landuse in categories) {
				categories << landuse;
			}

		}

		ask active_cell_calibrate {
			if not (landuse in categories) {
				categories << landuse;
			}

		}

		write "In kiem tra categories: " + categories;
		v_kappa <- kappa(cell_calibrate collect (each.landuse), land_cell collect (each.landuse), categories);
		write "Kappa: " + v_kappa;
	}

	action gan_landuse_hc {
		ask land_cell {
			landuse_hc <- cell_calibrate[self.grid_x, self.grid_y].landuse;
		}

	}

	action doc_dif_shifting_matrix {
		dif_shifting_matrix <- matrix(shiftable_eval_file);
		write "Ma tran Kho Khan" + dif_shifting_matrix;
	}

	action set_landunit {
//		loop dvdd_obj over: land_unit {
//			ask land_cell overlapping dvdd_obj {
//				madvdd <- dvdd_obj.madvdd;
//			}
//
//		}
		loop soiltype_obj over: soiltype {
			ask land_cell overlapping soiltype_obj {
				soil_type <- soiltype_obj.soil_name;
			}
		}
		loop sal_obj over: salinity {
			ask land_cell overlapping sal_obj {
				salinity_level <- sal_obj.salinity_level;
			}
		}
		loop saltime_obj over: salinity_time {
			ask land_cell overlapping saltime_obj {
				salinity_time_level <- saltime_obj.salinity_time_level;
			}
		}
		
	}

	action cal_area_lu_sim {
		float dt_tsl;
		float dt_luc;
		float dt_luk;
		float dt_cln;
		float dt_bhk;
		// ghi dòng tiêu đề kết quả hiện trạng ra file CSV
		// nếu có nhiều loại đất thì thêm vào
		save "district_name, dt_luc,dt_tsl,dt_luk,dt_cln,dt_bhk" to: "../results/hientrang_huyen.csv" type: "csv" rewrite: true;
		loop district_obj over: district {
		// duyệt hết các cell chồng lắp với huyện để tính diên diện tich
			dt_luc <- 0.0;
			dt_tsl <- 0.0;
			dt_luk <- 0.0;
			dt_cln <- 0.0;
			dt_bhk <- 0.0;
			ask land_cell overlapping district_obj {
				if (landuse = 5) {
					dt_luc <- dt_luc + 400 * 400 / 10000;
				}

				if (landuse = 34) {
					dt_tsl <- dt_tsl + 400 * 400 / 10000;
				}

				if (landuse = 6) {
					dt_luk <- dt_luk + 400 * 400 / 10000;
				}

				if (landuse = 14) {
					dt_cln <- dt_cln + 400 * 400 / 10000;
				}

				if (landuse = 12) {
					dt_bhk <- dt_bhk + 400 * 400 / 10000;
				}

				grid_value <- float(landuse);
			}
			// Lưu kết quả tính từng loại đất vào biến toại đát ương ứng của huyện
			district_obj.total_rice_h <- dt_luc;
			district_obj.total_shrimp_h <- dt_tsl;
			district_obj.total_riceother_h <- dt_luk;
			district_obj.total_fruit_h <- dt_cln;
			district_obj.total_crops_h <- dt_bhk;
			save
			[district_obj.district_name, district_obj.total_rice_h, district_obj.total_shrimp_h, district_obj.total_riceother_h, district_obj.total_fruit_h, district_obj.total_crops_h]
			to: "../results/hientrang_huyen.csv" type: "csv" rewrite: false;
			write district_obj.district_name + ';' + dt_luc + ';' + dt_tsl + ';' + dt_luk + ';' + dt_cln + ';' + dt_bhk;
		}
		// ghu kết quả huyen ra file shapfile thuộc tính gồm 3 cột: ten huyen, dt luc, dt tsl. Nếu có thểm thì cứ thêm loại đất vào
		save district to: "../results/district_landuse.shp" type: "shp" attributes:
		["district_name"::district_name, "dt_luc"::total_rice_h, "dt_tsl"::total_shrimp_h, "dt_luk"::total_riceother_h, "dt_cln"::total_fruit_h, "dt_bhk"::total_crops_h];
		save land_cell to: "../results/hientrang_sim" + (2005 + cycle) + ".tif" type: "geotiff";
		write "Đa tinh dien tich hien trang theo huyen xong";
	}

	action cal_area_lu_obs {
		float dt_tsl;
		float dt_luc;
		float dt_luk;
		float dt_cln;
		float dt_bhk;
		// ghi dòng tiêu đề kết quả hiện trạng ra file CSV
		// nếu có nhiều loại đất thì thêm vào
		save "district_name, dt_luc,dt_tsl,dt_luk,dt_cln,dt_bhk" to: "../results/hientrang_huyen2010.csv" type: "csv" rewrite: true;
		loop district_obj over: district {
		// duyệt hết các cell chồng lắp với huyện để tính diên diện tich
			dt_luc <- 0.0;
			dt_tsl <- 0.0;
			dt_luk <- 0.0;
			dt_cln <- 0.0;
			dt_bhk <- 0.0;
			ask cell_calibrate overlapping district_obj { // 2010 là cell_calibrate
				if (landuse = 5) {
					dt_luc <- dt_luc + 400 * 400 / 10000;
				}

				if (landuse = 34) {
					dt_tsl <- dt_tsl + 400 * 400 / 10000;
				}

				if (landuse = 6) {
					dt_luk <- dt_luk + 400 * 400 / 10000;
				}

				if (landuse = 14) {
					dt_cln <- dt_cln + 400 * 400 / 10000;
				}

				if (landuse = 12) {
					dt_bhk <- dt_bhk + 400 * 400 / 10000;
				}

			}
			// Lưu kết quả tính từng loại đất vào biến toại đát ương ứng của huyện
			district_obj.total_rice_h <- dt_luc;
			district_obj.total_shrimp_h <- dt_tsl;
			district_obj.total_riceother_h <- dt_luk;
			district_obj.total_fruit_h <- dt_cln;
			district_obj.total_crops_h <- dt_bhk;
			save
			[district_obj.district_name, district_obj.total_rice_h, district_obj.total_shrimp_h, district_obj.total_riceother_h, district_obj.total_fruit_h, district_obj.total_crops_h]
			to: "../results/hientrang_district2010.csv" type: "csv" rewrite: false;
			write district_obj.district_name + ';' + dt_luc + ';' + dt_tsl + ';' + dt_luk + ';' + dt_cln + ';' + dt_bhk;
		}
		// ghu kết quả district ra file shapfile thuộc tính gồm 3 cột: ten district, dt luc, dt tsl. Nếu có thểm thì cứ thêm loại đất vào
		save district to: "../results/district2010_landuse.shp" type: "shp" attributes:
		["district_name"::district_name, "dt_luc"::total_rice_h, "dt_tsl"::total_shrimp_h, "dt_luk"::total_riceother_h, "dt_cln"::total_fruit_h, "dt_bhk"::total_crops_h];
		//save cell_calibrate to:"../results/hientrang_2010.tif" type:"geotiff";  Cái này ko cần vì bản đồ 2010 đã có 
		//write "Đa tinh dien tich hien trang theo huyen xong";

	}

	reflex main_reflex {
		ask active_cell {
		//do check_LU_density;
			do cal_capability_index;
		}

		// xetb da tieu chi
		ask active_cell {
			do landuse_eval;
			do select_landuse;
			do set_color;
		}

		write "Tieu chi :" + creteria;
		// kiem tra ma tra nthich nghi
//		write "kiem tra ma tran thich nghi:";
//		string st;
//		int i <- 0;
//		int j <- 0;
//		loop i from: 1 to: suitability_matrix.rows - 1 {
//			st <- "";
//			loop j from: 3 to: suitability_matrix.columns - 1 {
//				st <- st + ";" + suitability_matrix[j, i];
//			}
//
//			write st;
//		}

		// test kiem tra các thong so 1 cell
		ask land_cell at 19737 {
			list<list> cands <- landuse_eval();
			write "danh sách cand:" + cands;
			write "Tieu chi :" + creteria;
			int choice <- 0;
			//if (landuse=5 or landuse=6 or landuse=14 ){//những loại đất có khả năng chuyển
			choice <- weighted_means_DM(cands, creteria);

			//choice tra vi tri ung vien trong danh sach
			if (choice = 0) {
			//if flip(0.05){
			//if check_suitability(madvdd,5)>0{	
				landuse <- 5;
				//}
			}

			if (choice = 1) {
			//if check_suitability(madvdd,34)>0{
				landuse <- 34;
				//}	
			}

			if (choice = 2) {
			//if check_suitability(madvdd,6)>0{
				landuse <- 6;
				//}
			}

			if (choice = 3) {
			//	if check_suitability(madvdd,14)>0{
				landuse <- 14;
				//}
			}

			if (choice = 4) {
				landuse <- 12;
			}

//			write "Lua chon tra ve cho land_cell:" + choice;
//			write "madvdd cua cell :" + madvdd + " ;muc thich nghi TSL:" + check_suitability(madvdd, 34);
//			write "muc thich nghi LUC:" + check_suitability(madvdd, 5);
//			write "muc thich nghi LUK:" + check_suitability(madvdd, 6);
//			write "muc thich nghi CLN:" + check_suitability(madvdd, 14);
//			write "muc thich nghi BHK:" + check_suitability(madvdd, 12);
		}

		do tinhtongdt;
		if (cycle = 5) {
			do tinh_kappa;
			//	do cal_area_lu_sim;
			if not batch_mode {
				do pause;	
			} 
			
		}

	}

	init {
		create district from: district_file with: [district_name::read("district_name")];
		do build_suitability_map ; //doc_matran_TN;
		do doc_dif_shifting_matrix;
		do doc_matran_Loinhuan;
		
		create river from: river_file;
		create road from: road_file;
		create land_unit from: landunit_file with: [madvdd::int(read('dvdd'))];
		create soiltype from:soiltype_file with:[soil_name::read('Land_name_')] ;
		create salinity from:salinity_file with:[salinity_level::int(read('Code')),sal_note::read('salinity')] ;
		create salinity_time from:salt_time_file with:[salinity_time_level::int(read('Codetime')),salt_time_note::read('Salt_time')] ;
		ask active_cell {
			do set_color;
		}

		ask active_cell_calibrate {
			do set_color_hc;
		}

		do gan_landuse_hc;
		do set_landunit;
		creteria <- [["name"::"lancan", "weight"::w_lancan], ["name"::"thichnghi", "weight"::w_suitability],
		["name"::"khokhan","weight"::w_diff_shifting],["name"::"loinhuan","weight"::w_benefit]
];
		//do cal_area_lu_2005;
		do cal_area_lu_obs;
	}

}

grid land_cell file: cell_file control: reflex neighbors: 8 {
	int landuse <- int(grid_value);
	rgb color;
	int landuse_hc <- int(grid_value);
	int madvdd;
	string soil_type;
	int salinity_level;
	int salinity_time_level;

	init {
	}

	action set_color {
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

		if (landuse = 12) {
			color <- rgb(255, 240, 180);
		}

	}

	action cal_capability_index {
	//hesochuyendoi_tsl <- w_lancan_TSL*shrimp_density_index;
	//hesochuyendoi_luk <- w_lancan_LUK*ricecrops_density_index;
	//hesochuyendoi_luc <- w_lancan_LUC*rice_density_index;
	//hesochuyendoi_cln <- w_lancan_CLN*fruit_density_index;
	//hesochuyendoi_bhk <- w_lancan_BHK*crops_density_index;

	}

//	float check_suitability (int v_madvdd, int LUT) {
//		float kqthichnghi <- 1.0;
//		int i <- 0;
//		int j <- 0;
//		loop i from: 1 to: suitability_matrix.rows - 1 {
//			if (int(suitability_matrix[0, i]) = v_madvdd) {
//				loop j from: 3 to: suitability_matrix.columns - 1 {
//					if (int(suitability_matrix[j, 0]) = LUT) {
//						kqthichnghi <- float(suitability_matrix[j, i]);
//					}
//
//				}
//
//			}
//
//		}
//
//		return kqthichnghi;
//	}
//	float check_suitability (string vSoil, int sal, int sal_time, int LUT) {
//		float kqthichnghi <- 1.0;
//		int i <- 0;
//		int j <- 0;
//		loop i from: 1 to: suitability_matrix.rows - 1 {
//			if (int(suitability_matrix[0, i]) = v_madvdd) {
//				loop j from: 3 to: suitability_matrix.columns - 1 {
//					if (int(suitability_matrix[j, 0]) = LUT) {
//						kqthichnghi <- float(suitability_matrix[j, i]);
//					}
//
//				}
//
//			}
//
//		}
//
//		return kqthichnghi;
//	}
	int getSalinityLevel(int sal) {
		int kq<-2; 
	 	 if (sal <=2){
	 	 	kq<-2;
	 	 }
	 	 else {
	 		 kq<-3; 
	 	}
	 	return kq;
	}
	 int getSaltTime(int sal_time){
	 	 //1:	0		3:	3	6:	6	7:	>6
	 	 //return: 1: <=3 ; 2: >=6
	 	 int kq<-1; 
	 	 if (sal_time <=3){
	 	 	kq<-1;
	 	 }
	 	 else {
	 		 kq<-2; 
	 	}
	 	return kq;
	 }

	list<list> landuse_eval {
		list<list> candidates;
		list<float> candluc;
		list<float> candtsl;
		list<float> candluk;
		list<float> candcln;
		list<float> candbhk;
		map<int,float> landSuitability;
		string slandunit <- soil_type+string(getSalinityLevel(salinity_level))+string(getSaltTime(salinity_time_level));
		landSuitability <- suitability_map[slandunit];
		candluc << cal_lu_density(5);
		
		candluc << landSuitability[5]; // check_suitability(madvdd, 5);
		candluc << check_shiftable(landuse, 5);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candluc << get_benefit(5);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5
		//dua dac tinh ung vien tsl
		candtsl << cal_lu_density(34);
		candtsl << landSuitability[34]; 
		candtsl << check_shiftable(landuse, 34);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candtsl << get_benefit(34);
		//dua dac tinh ung vien hnk
		//canddtl<<chiso_DTL_lancan;

		//canddtl<<chiso_DTL_thichnghi;
		//dua dac tinh ung vien lnk
		candluk << cal_lu_density(6);
		candluk << landSuitability[6]; 
		candluk << check_shiftable(landuse, 6);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candluk << get_benefit(6);
		//dua dac tinh ung vien rst
		candcln << cal_lu_density(14);
		candcln << landSuitability[14]; 
		candcln << check_shiftable(landuse, 14);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candcln << get_benefit(14);
		
		candbhk << cal_lu_density(12);
		candbhk << landSuitability[12]; 
		candbhk << check_shiftable(landuse, 12);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candbhk << get_benefit(12);
		//nap cac ung vien vao danh sach candidates
		candidates << candluc;
		candidates << candtsl;
		candidates << candluk;
		candidates << candcln;
		candidates << candbhk;
		return candidates;
	}

	action select_landuse {
		list<list> cands <- landuse_eval();
		int choice <- 0;
		//if (landuse=5 or landuse=6 or landuse=14 ){//những loại đất có khả năng chuyển
		choice <- weighted_means_DM(cands, creteria);
		//choice tra vi tri ung vien trong danh sach
		if (choice = 0) {
		//if flip(0.05){
		//if check_suitability(madvdd,5)>0{	
			landuse <- 5;
			//}
		}

		if (choice = 1) {
		//if check_suitability(madvdd,34)>0{
			landuse <- 34;
			//}	
		}

		if (choice = 2) {
		//if check_suitability(madvdd,6)>0{
			landuse <- 6;
			//}
		}

		if (choice = 3) {
		//	if check_suitability(madvdd,14)>0{
			landuse <- 14;
			//}
		}

		if (choice = 4) {
			landuse <- 12;
		}

	}

	int check_shiftable (int landuse1, int landuse2) {
		int kqkhokhan <- 0;
		int i <- 0;
		int j <- 0;
		loop i from: 1 to: dif_shifting_matrix.rows - 1 {
			if (dif_shifting_matrix[0, i] = landuse1) {
				loop j from: 1 to: dif_shifting_matrix.columns - 1 {
					if (dif_shifting_matrix[j, 0] = landuse2) {
						kqkhokhan <- int(dif_shifting_matrix[j, i]);
					}
				}
			}
		}
		return kqkhokhan;
	}
	// get benefit of land use
	int get_benefit(int landuse1){
		int kq <-0;
		int i <- 0;
		int j <- 0;
		loop i from: 1 to: bebefit_matrix.rows - 1 {
			if (bebefit_matrix[0, i] = landuse1) {
				kq<- int(bebefit_matrix[0, i]);
			}
		}
		return kq;
	}
	
	float cal_lu_density (int lu) {
		float kq <- 0.0;
		list<land_cell> cell_lancan <- (self neighbors_at 1);
		kq <- (cell_lancan count (each.landuse = lu)) / 8;
		return kq;
	}
}

species river control: reflex {
	int id;
	rgb color <- rgb(160, 255, 255);

	init {
	}
}

species road control: reflex {
	int id;
	rgb color <- rgb(255, 170, 50);

	init {
	}

}
species soiltype  {
	string soil_name;  //Dat phen hoat dong,	Dat cat	,Dat man,	Dat phu sa,	Dat phen tiem tang
	
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
}

species salinity  {
	int  salinity_level;  //1:<4; 2:	8-Apr	3	12-Aug	4	20-Dec	5 >=20
	string sal_note;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
}
species salinity_time  {
	int  salinity_time_level;  //1:	0		3:	3	6:	6	7:	>6
	
	string salt_time_note;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
}
grid cell_calibrate file: cell_calibrate_file control: reflex neighbors: 8 {
	int landuse <- int(grid_value);
	rgb color;

	init {
	}

	action set_color_hc {
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

		if (landuse = 12) {
			color <- rgb(255, 240, 180);
		}

	}

}

species land_unit control: reflex {
	int madvdd;
	rgb color <- rgb(rnd(255), rnd(255), rnd(255));

	init {
	}

}

species district control: reflex {
	string district_name;
	float total_rice_h;
	float total_shrimp_h;
	float total_riceother_h;
	float total_fruit_h;
	float total_crops_h;

	init {
	}

}

experiment "LanduseModel" type: gui {
	parameter "Weight density" var: w_lancan <- 0.8;
	parameter "Weight suitability" var: w_suitability <- 0.8;
	parameter 'Weight difficulties' var: w_diff_shifting min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight bebefit:' var: w_benefit min: 0.1 max: 1.0 step:0.1;
	output {
		display lu_sim type: java2D {
			grid land_cell;
			species river;
			species road;
		}
		display lu_charts type: java2D {
			chart "Layer" type: series background: rgb(255, 255, 255) {
				data "Tong dt lua" style: line value: total_rice color: #yellow;
				data "Tong dt tsl" style: line value: total_shrimp color: #blue;
				data "Tong dt luk" style: line value: total_riceother color: #orange;
				data "Tong dt cln" style: line value: total_fruit color: #green;
				data "Tong dt bhk" style: line value: total_crops color: #red;
			}
		}
		display lu_obs type: java2D {
			grid cell_calibrate;
		}
	}
}

experiment "Calibrate" type: batch repeat: 1 keep_seed: true until: ( time > 5 ){
	parameter 'Weight density' var: w_lancan min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight suitability:' var: w_suitability min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight difficulties' var: w_diff_shifting min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight bebefit:' var: w_benefit min: 0.1 max: 1.0 step:0.1;
	init {
		batch_mode <- true;
	}
	
	//method genetic  maximize: v_kappa;
	method genetic pop_dim: 3 crossover_prob: 0.7 mutation_prob: 0.1 improve_sol: true stochastic_sel: false
	nb_prelim_gen: 1 max_gen: 5  maximize: v_kappa ;
}