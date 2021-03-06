/*
 * 
 * 
 */
model landuse_st_v1

global control: reflex {
	file cell_file <- grid_file("../includes/landuse/st2005x100align.tif");
	file river_file <- shape_file('../includes/kenhrach2010_region.shp');
	file road_file <- shape_file('../includes/duong2010_region.shp');
	file district_file <- shape_file('../includes/huyenST_2019_region.shp');
	file dyke_file <- shape_file('../includes/soctrang_debao2010_region.shp');//soctrang_debao2010_region
	file cell_calibrate_file <- grid_file("../includes/landuse/st2010x100align.tif");
//	file landunit_file <- shape_file('../includes/dvdd_hientai_region.shp');
	// 3 layers of land unit map
	file soiltype_file <- shape_file('../includes/LMU/soiltype_region.shp');
	file salinity_file <- shape_file('../includes/LMU/salinity2015_region.shp');
	file salinity05_file <- shape_file('../includes/LMU/salinity2005_region.shp');
	file salt_time_file <- shape_file('../includes/LMU/salt_time_ST_2010_region.shp');
	file salt_time05_file <- shape_file('../includes/LMU/salt_time_ST_2005_region.shp');
	file bebefit_file <- csv_file('../includes/dataset/benefit.csv', false);
	file landsuitability_2_file <- csv_file('../includes/dataset/landsuitability.csv', false);
	file shiftable_eval_file <- csv_file('../includes/dataset/danhgia_khokhan_chuyendoi.csv', false);
	list<land_cell> active_cell <- land_cell where (each.grid_value >1.0);
	float total_rice;
	float total_riceother;
	float total_shrimp;
	float total_fruit;
	float total_rice_shrimp;
	float pixel_size <-100*100/10000;
	int v_year<-2005;
	
	matrix suitability_matrix;
	map<string, map<int,float>> suitability_map;	
	matrix bebefit_matrix;
	geometry shape <- envelope(cell_file);
	list<cell_calibrate> active_cell_calibrate <- cell_calibrate where (each.grid_value >1.0);
	float v_kappa <- 0.0;
	list creteria;
	float w_lancan <- 0.8;
	float w_suitability <- 0.6 ;
	matrix dif_shifting_matrix;
	map<string,float> kqkhokhanchuyendoi_map;
	float w_diff_shifting <- 0.6;
	float w_benefit <- 0.5;
 	bool batch_mode <-false;
	float total_crops;	
	// list of land use type and color
	map<int,rgb> LUT <-[0::#white,5::#yellow,6:: #lightyellow,34:: #cyan,14::#darkgreen,12::#lightgreen,101::rgb(40, 150, 120),1::#lightgray];
	// list of salinity level
	map<int,rgb>lstSalinity_color<-[0::#white,1::rgb(250,170,170),2::rgb(240,140,140),3::rgb(230,80,80),4::rgb(230,30,30),5::rgb(150,20,20)];
	map<int,rgb>lstSalinity_time_color<-[0::#white,1::rgb(250,210,210),3::rgb(240,160,160),6::rgb(230,80,80),5::rgb(230,30,30),7::rgb(150,20,20)];
	list<int> lstSalinity_level <-[1,2,3,4,5];
	// markov matrix 
	map<int,map<int,list<float>>> salinity_markov_map;  //vungde <salinity_level, sooscell>
	init {
		create district from: district_file with: [district_name::read("district_name")];
		do build_suitability_map ; //doc_matran_TN;
		do doc_dif_shifting_matrix;
		do doc_matran_Loinhuan;
		create river from: river_file;
		create road from: road_file;
//		create land_unit from: landunit_file with: [madvdd::int(read('dvdd'))];
		create soiltype from:soiltype_file with:[soil_name::read('Land_name_')] ;
		create salinity from:salinity05_file with:[salinity_level::int(read('Code')),sal_note::read('salinity')] ;
		create salinity_obs from:salinity_file with:[salinity_level::int(read('Code')),sal_note::read('salinity')] ;
		create salinity_time from:salt_time05_file with:[salinity_time_level::int(read('Codetime')),salt_time_note::read('Salt_time')] ;
		create salinity_time_obs from:salt_time_file with:[salinity_time_level::int(read('Codetime')),salt_time_note::read('Salt_time')] ;
		create dyke from:dyke_file with:[dyke_region::int(read('De'))] ;
		ask active_cell_calibrate {
			do set_color_hc;
		}
		do gan_landuse_hc;
		do set_envi_layer; // set LMU layer: salinity, salt_time, soiltype
		do set_dyke_region;
		// built markov salinity matrix ( map)
		do built_salinity_markov_maps;
		// cretiria for landuse changes
		creteria <- [["name"::"lancan", "weight"::w_lancan], ["name"::"thichnghi", "weight"::w_suitability],
		["name"::"khokhan","weight"::w_diff_shifting],["name"::"loinhuan","weight"::w_benefit]];
		//do cal_area_lu_2005;
		//do cal_area_lu_obs;
		ask active_cell {
			do set_color;
			color_salinity <- lstSalinity_color[salinity_level];
			color_salinity_time <- lstSalinity_time_color[salinity_time_level];
		}
		do sal_instrusion_canal;
//		// ?????i gi?? tr??? l??a t??m: 
//		loop vungtom_obj over: dyke {
//			ask land_cell overlapping vungtom_obj {
//				if (landuse =6){
//					grid_value<-101.0;
//				}
//				
//				
//			}
//			
//
//		}
//		save land_cell to: "../results/input/st2015x100align.tif" type: "geotiff";
	}
	action tinhtongdt {
		total_rice <- 0.0;
		total_shrimp <- 0.0;
		total_rice_shrimp <- 0.0;
		total_riceother <- 0.0;
		total_fruit <- 0.0;
		total_crops <- 0.0;
		ask active_cell {
			if (landuse = 5) {
				total_rice <- total_rice + pixel_size;
			}
			if (landuse = 34) {
				total_shrimp <- total_shrimp +pixel_size;
			}
			if (landuse = 101) {
				total_rice_shrimp <- total_rice_shrimp +pixel_size;
			}
			
			if (landuse = 6) {
				total_riceother <- total_riceother + pixel_size;
			}
			if (landuse = 14) {
				total_fruit <- total_fruit + pixel_size;
			}
			if (landuse = 12) {
				total_crops <- total_crops + pixel_size;
			}
		}
		write "Tong dt lua: " + total_rice;
		write "Tong dt ts: " + total_shrimp;
		write "Tong dt lua_tom: " + total_rice_shrimp;
		write "Tong dt lua khac: " + total_riceother;
		write "Tong dt cay an qua: " + total_fruit;
		write "Tong dt cay hang nam: " + total_crops;		
		save land_cell to: "../results/hientrang_sim.tif" type: "geotiff";
		save [v_year,total_rice, total_shrimp, total_rice_shrimp,total_riceother, total_fruit, total_crops]
			to: "../results/hientrang_huyen_sim.csv" type: "csv" rewrite: false;		
	}
// built markov matrix:
	action built_salinity_markov_maps {
		list<int> lstDykeRegion <- remove_duplicates(dyke collect each.dyke_region);
//		lstSalinity_level <-remove_duplicates(salinity collect each.salinity_level);
		write "DS vung De:" + lstDykeRegion;
		write "Ds di man:"+ lstSalinity_level;
		loop regiondyke over: lstDykeRegion {
			list<land_cell> cell_dyke_region <- land_cell where (each.dyke_region = regiondyke);
			map<int,list<float>> the_map <- [];
			loop salinity1 over: lstSalinity_level {
				list<float> transition <- [];
				loop salinity2 over: lstSalinity_level {
					transition << float(land_cell count ((each.salinity_level = salinity1) and (each.salinity_level_obs = salinity2)));
				}
				the_map[salinity1] <- transition;
			}
			salinity_markov_map[regiondyke] <- the_map;
		}
		write "matran chuyen doi:"+ salinity_markov_map;
	}
	
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
		list<int> categories <- [0,1];
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
		int i <- 0;
		int j <- 0;
		loop i from: 1 to: dif_shifting_matrix.rows - 1 {
			int landuse1 <- int(dif_shifting_matrix[0, i]);
			loop j from: 1 to: dif_shifting_matrix.columns - 1 { //do tung cot cua matran
				int landuse2 <- int(dif_shifting_matrix[j, 0]);
				kqkhokhanchuyendoi_map <+ "" + landuse1 + " " + landuse2::float(dif_shifting_matrix[j, i]);
			}
		}
		write "Map kho khan:" + kqkhokhanchuyendoi_map;
	}
	action set_dyke_region{
		loop dyke_obj over: dyke{
			ask active_cell overlapping dyke_obj{
				dyke_region <- dyke_obj.dyke_region;
			}
		}
	}
	action set_envi_layer {
		loop soiltype_obj over: soiltype {
			ask active_cell overlapping soiltype_obj {
				soil_type <- soiltype_obj.soil_name;
			}
		}
		loop sal_obj over: salinity {
			ask active_cell overlapping sal_obj {
				salinity_level <- sal_obj.salinity_level;
			}
		}
		loop saltime_obj over: salinity_time {
			ask active_cell overlapping saltime_obj {
				salinity_time_level <- saltime_obj.salinity_time_level;
			}
		}
		// salinity observe 
		loop sal_obj over: salinity_obs {
			ask active_cell overlapping sal_obj {
				salinity_level_obs <- sal_obj.salinity_level;
			}
		}
		loop saltime_obj over: salinity_time_obs {
			ask active_cell overlapping saltime_obj {
				salinity_time_level_obs <- saltime_obj.salinity_time_level;
			}
		}
	}
	action cal_area_lu_district_sim {
		float dt_tsl;
		float dt_luc;
		float dt_luk;
		float dt_cln;
		float dt_bhk;
		float dt_ricetsl;
		// ghi d??ng ti??u ????? k???t qu??? hi???n tr???ng ra file CSV
		// n???u c?? nhi???u lo???i ?????t th?? th??m v??o
		loop district_obj over: district {
		// duy???t h???t c??c cell ch???ng l???p v???i huy???n ????? t??nh di??n di???n tich
			dt_luc <- 0.0;
			dt_tsl <- 0.0;
			dt_luk <- 0.0;
			dt_cln <- 0.0;
			dt_bhk <- 0.0;
			dt_ricetsl <-0.0;
			ask land_cell overlapping district_obj {
				if (landuse = 5) {
					dt_luc <- dt_luc + pixel_size;
				}
				if (landuse = 34) {
					dt_tsl <- dt_tsl + pixel_size;
				}
				if (landuse = 101) {
					dt_tsl <- dt_ricetsl + pixel_size;
				}
				
				if (landuse = 6) {
					dt_luk <- dt_luk + pixel_size;
				}
				if (landuse = 14) {
					dt_cln <- dt_cln +pixel_size;
				}
				if (landuse = 12) {
					dt_bhk <- dt_bhk + pixel_size;
				}
				grid_value <- float(landuse);
			}
			// L??u k???t qu??? t??nh t???ng lo???i ?????t v??o bi???n to???i ????t ????ng ???ng c???a huy???n
			district_obj.total_rice_h <- dt_luc;
			district_obj.total_shrimp_h <- dt_tsl;
			district_obj.total_riceother_h <- dt_luk;
			district_obj.total_rice_shrimp_h <- dt_ricetsl;
			district_obj.total_fruit_h <- dt_cln;
			district_obj.total_crops_h <- dt_bhk;
			save
			[v_year,district_obj.district_name, district_obj.total_rice_h, district_obj.total_shrimp_h,district_obj.total_rice_shrimp_h, district_obj.total_riceother_h, district_obj.total_fruit_h, district_obj.total_crops_h]
			to: "../results/hientrang_huyen_sim.csv" type: "csv" rewrite: false;
			//write district_obj.district_name + ';' + dt_luc + ';' + dt_tsl + ';' + dt_luk + ';' + dt_cln + ';' + dt_bhk;
		}
		// ghu k???t qu??? huyen ra file shapfile thu???c t??nh g???m 3 c???t: ten huyen, dt luc, dt tsl. N???u c?? th???m th?? c??? th??m lo???i ?????t v??o
//		save district to: "../results/district_landuse.shp" type: "shp" attributes:
	//	["district_name"::district_name, "dt_luc"::total_rice_h, "dt_tsl"::total_shrimp_h, "dt_luk"::total_riceother_h, "dt_cln"::total_fruit_h, "dt_bhk"::total_crops_h];
//		write "??a tinh dien tich hien trang theo huyen xong";
	}

	action cal_area_lu_obs {
		float dt_tsl;
		float dt_luc;
		float dt_luk;
		float dt_cln;
		float dt_bhk;
		// ghi d??ng ti??u ????? k???t qu??? hi???n tr???ng ra file CSV
		// n???u c?? nhi???u lo???i ?????t th?? th??m v??o
		loop district_obj over: district {
		// duy???t h???t c??c cell ch???ng l???p v???i huy???n ????? t??nh di??n di???n tich
			dt_luc <- 0.0;
			dt_tsl <- 0.0;
			dt_luk <- 0.0;
			dt_cln <- 0.0;
			dt_bhk <- 0.0;
			ask cell_calibrate overlapping district_obj { // 2010 l?? cell_calibrate
				if (landuse = 5) {
					dt_luc <- dt_luc + pixel_size;
				}
				if (landuse = 34) {
					dt_tsl <- dt_tsl + pixel_size;
				}
				if (landuse = 6) {
					dt_luk <- dt_luk + pixel_size;
				}
				if (landuse = 14) {
					dt_cln <- dt_cln + pixel_size;
				}
				if (landuse = 12) {
					dt_bhk <- dt_bhk + pixel_size;
				}
			}
			// L??u k???t qu??? t??nh t???ng lo???i ?????t v??o bi???n to???i ????t ????ng ???ng c???a huy???n
			district_obj.total_rice_h <- dt_luc;
			district_obj.total_shrimp_h <- dt_tsl;
			district_obj.total_riceother_h <- dt_luk;
			district_obj.total_fruit_h <- dt_cln;
			district_obj.total_crops_h <- dt_bhk;
			save
			[v_year, district_obj.district_name, district_obj.total_rice_h, district_obj.total_shrimp_h, district_obj.total_riceother_h, district_obj.total_fruit_h, district_obj.total_crops_h]
			to: "../results/hientrang_district2015.csv" type: "csv" rewrite: false;
		//	write district_obj.district_name + ';' + dt_luc + ';' + dt_tsl + ';' + dt_luk + ';' + dt_cln + ';' + dt_bhk;
		}
		// ghu k???t qu??? district ra file shapfile thu???c t??nh g???m 3 c???t: ten district, dt luc, dt tsl. N???u c?? th???m th?? c??? th??m lo???i ?????t v??o
//		save district to: "../results/district2010_landuse.shp" type: "shp" attributes:
//		["district_name"::district_name, "dt_luc"::total_rice_h, "dt_tsl"::total_shrimp_h, "dt_luk"::total_riceother_h, "dt_cln"::total_fruit_h, "dt_bhk"::total_crops_h];
		//save cell_calibrate to:"../results/hientrang_2010.tif" type:"geotiff";  C??i n??y ko c???n v?? b???n ????? 2010 ???? c?? 
		//write "??a tinh dien tich hien trang theo huyen xong";
	}
	action cal_salinity_time_index{
		// t??nh ch??? s?? l??n c???n v??ng ????? m???n
		ask active_cell where (each.dyke_region>1){
			list<land_cell>cell_lancan<-(self neighbors_at 3);
			sal_time_3 <-(cell_lancan count(each.salinity_time_level =3 ))/8;
			sal_time_6 <-(cell_lancan count(each.salinity_time_level =6 ))/8;
			sal_time_7 <-(cell_lancan count(each.salinity_time_level =7 ))/8;
		}
	}
	action salinity_time_dynamic{
		list<land_cell>ds_man1 <-[];
		ds_man1<-active_cell where (each.salinity_time_level<7 and each.sal_time_6>0) sort_by each.sal_time_6;
		//ds_man1 <-last(100,ds_man1);
		ask ds_man1{// t??m c??c cell t??? danh s??ch c??c s??? kh??ng m???n t??? d?????i l??n 1 s??? cell
			if dyke_region>1{
				salinity_time_level<-6;// g??n th??nh m???n 6t	
				color_salinity_time <-lstSalinity_time_color[salinity_time_level];		
			}
		}
		ds_man1<-active_cell where (each.salinity_time_level<7 and each.sal_time_7>0) ;
		//ds_man1 <-last(100,ds_man1);
		ask ds_man1{// t??m c??c cell t??? danh s??ch c??c s??? kh??ng m???n t??? d?????i l??n 1 s??? cell
			if dyke_region>1{
				salinity_time_level<-7;// g??n th??nh m???n 6t	
				color_salinity_time <-lstSalinity_time_color[salinity_time_level];		
			}
		}
	}
	action cal_salinity_capa_index{
		// t??nh ch??? s?? l??n c???n v??ng ????? m???n
		ask active_cell where (each.dyke_region>1){
			list<land_cell>cell_lancan<-(self neighbors_at 2);
			chiso_man2 <-(cell_lancan count(each.salinity_level =2 ))/8;
			chiso_man3 <-(cell_lancan count(each.salinity_level =3 ))/8;
			chiso_man4 <-(cell_lancan count(each.salinity_level =4 ))/8;
			if chiso_man2>0{
				chiso_man2 <- chiso_man2 + suitability;
				salinity_level<-2;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];	
			}
			if chiso_man3>0{
				chiso_man3 <- chiso_man3 + suitability;
				salinity_level<-3;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];	
			}
			if chiso_man4>0{
				chiso_man4 <- chiso_man4 + suitability;
				salinity_level<-4;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];	
			}
		}
	}
	action salinity_dynamic_river{
		// t??nh ch??? s?? l??n c???n v??ng ????? m???n
		ask active_cell where (each.dyke_region>1 and each.suitability=1){
			list<land_cell>cell_lancan<-(self neighbors_at 2);
			chiso_man2 <-(cell_lancan count(each.salinity_level =2 ))/8;
			chiso_man3 <-(cell_lancan count(each.salinity_level =3 ))/8;
			chiso_man4 <-(cell_lancan count(each.salinity_level =4 ))/8;
			if chiso_man2>0{
				chiso_man2 <- chiso_man2 + suitability;
				salinity_level<-2;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];	
			}
			if chiso_man3>0{
				chiso_man3 <- chiso_man3 + suitability;
				salinity_level<-3;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];	
			}
			if chiso_man4>0{
				chiso_man4 <- chiso_man4 + suitability;
				salinity_level<-4;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];	
			}
		}
	}
	
	action salinity_dynamic{
		list<land_cell>ds_man1 <-[];

		ds_man1<-active_cell where (each.salinity_level<3 and each.chiso_man3>0) sort_by each.chiso_man3;
		//ds_man1 <-last(100,ds_man1);
		ask ds_man1{// t??m c??c cell t??? danh s??ch c??c s??? kh??ng m???n t??? d?????i l??n 1 s??? cell
			if dyke_region>1{
				salinity_level<-3;// g??n th??nh m???n 6t	
				color_salinity <-lstSalinity_color[salinity_level];		
			}
		}
	}
	action markov_salinity{
		ask shuffle(active_cell where (each.dyke_region>=2 and each.salinity_level<=3 and each.changed_sal=false)){
			int salinity_tmp<-salinity_level;
//			if (flip(1/5)) {
				list<float> vals <- salinity_markov_map[dyke_region][salinity_level];
				int index <- rnd_choice(vals);
				salinity_level <- lstSalinity_level[index];
				color_salinity <-lstSalinity_color[salinity_level];
//				color_salinity10 <-salinity_color[salinity_level];
				changed_sal <- true;
//			}
		}
	}
	action sal_instrusion_canal{
		list<river> lstCanal_out_dyke;
//		lstCanal_out_dyke <- river overlapping 	
		list<land_cell>lstCell <-[];
		loop v_dyke over:dyke where (each.dyke_region >1){ // c??c ??o???n s??ng ngo??i ????
			ask river overlapping (v_dyke-10#m){ // t??m c??c ??o???n s??ng n???m ngo??i ????
				out_dyke<-true;
				color <-#red;
				lstCell <- (active_cell overlapping (self+50#m)); // t??m c??c cell n???m trong b??n k??nh 50m t??? k??nh
				int maxSalinity <- max(lstCell collect each.salinity_level)	;				
//				write "Do man cao nhat gan song: "+		maxSalinity;
				ask lstCell {
					//salinity_level <- maxSalinity;
					//color_salinity <-lstSalinity_color[salinity_level];
					suitability <-1;
				}		
			}		
		}
		
	}
	reflex main_reflex {
//		action tinh toan chuyen doi salinity and salt time
		v_year <- 2005+cycle;  
//		do markov_salinity; 
		do salinity_dynamic_river; 
		do cal_salinity_capa_index;
		do salinity_dynamic;
//		do cal_salinity_time_index;
//		do salinity_time_dynamic;
//		
//////////////////////////////////////////////////////////////////////////
		// xetb da tieu chi
		ask active_cell {
			do landuse_eval;
			do select_landuse;
			do set_color;
		}
//		write "Tieu chi :" + creteria;

//		// test kiem tra c??c thong so 1 cell
//		ask land_cell where (each.dyke_region=2 and each.salinity_level=3) at 1500 {
//			list<float> vals <- salinity_markov_map[dyke_region][salinity_level];
//			write "dyke:" + dyke_region +" Salinity level: "+ salinity_level;
//			write "gia tri marlov man:"+ vals;
//			list<list> cands <- landuse_eval();
//			write "danh s??ch cand:" + cands;
//			write "Tieu chi :" + creteria;
//			int choice <- 0;
//			//if (landuse=5 or landuse=6 or landuse=14 ){//nh???ng lo???i ?????t c?? kh??? n??ng chuy???n
//			choice <- weighted_means_DM(cands, creteria);
//			//choice tra vi tri ung vien trong danh sach
//			if (choice = 0) {
//			//if flip(0.05){
//			//if check_suitability(madvdd,5)>0{	
//				landuse <- 5;
//				//}
//			}
//			if (choice = 1) {
//			//if check_suitability(madvdd,34)>0{
//				landuse <- 34;
//				//}	
//			}
//			if (choice = 2) {
//			//if check_suitability(madvdd,6)>0{
//				landuse <- 6;
//				//}
//			}
//			if (choice = 3) {
//			//	if check_suitability(madvdd,14)>0{
//				landuse <- 14;
//				//}
//			}
//			if (choice = 4) {
//				landuse <- 12;
//			}
//			write "Lua chon tra ve cho land_cell:" + choice;
//		}
		do tinhtongdt;
		if (cycle mod 5) = 0{
			save land_cell to: "../results/hientrang_sim"+v_year+".tif" type: "geotiff";
		}
		
		if (cycle = 5) {
			do tinh_kappa;
		}
		if (cycle >25)  {
			//	do cal_area_lu_sim;
			if not batch_mode {
				do pause;	
			} 
		}
	
	}
}

grid land_cell file: cell_file control: reflex neighbors: 8 {
	int landuse <- int(grid_value);
	rgb color <-LUT[landuse];
	rgb color_salinity<-lstSalinity_color[salinity_level];
	rgb color_salinity_time<-lstSalinity_color[salinity_time_level];
	rgb color_salinity10<-lstSalinity_color[salinity_level_obs];
	int landuse_hc <- int(grid_value);
	int madvdd;
	string soil_type;
	int salinity_level;
	int salinity_time_level;
	int salinity_level_obs; // 2015
	int salinity_time_level_obs; //2015
	int dyke_region;
	float chiso_man2 ;
	float chiso_man3 ;
	float chiso_man4 ;
	float sal_time_3 ;
	float sal_time_6 ;
	float sal_time_7  ;
	bool changed_sal<-false;
	int suitability <-0; // nh???ng ??i???m g???n s??ng r???ch ???????c g??n h??? s??? n??y = 1 ????? lan truy???n thu???n l???i 
	init {
	}
	aspect salinity_time_aspect{
		draw shape color:color_salinity_time border: color_salinity_time;
	}

	aspect salinity_aspect{
		draw shape color:color_salinity border: color_salinity;
	}
	action set_color {
		color <- LUT[landuse];
	}
	aspect salinity10{
		draw shape color:color_salinity10 border: color_salinity10;
	}
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
		candluc << xet_khokhanchuyendoi(landuse,5);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5
		//xet_khokhanchuyendoi(landuse, 34);	
		candluc << get_benefit(5);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5
		//dua dac tinh ung vien tsl
		candtsl << cal_lu_density(34);
		candtsl << landSuitability[34]; 
		candtsl << xet_khokhanchuyendoi(landuse, 34);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candtsl << get_benefit(34);
		//dua dac tinh ung vien hnk
		//canddtl<<chiso_DTL_lancan;

		//canddtl<<chiso_DTL_thichnghi;
		//dua dac tinh ung vien lnk
		candluk << cal_lu_density(6);
		candluk << landSuitability[6]; 
		candluk << xet_khokhanchuyendoi(landuse, 6);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candluk << get_benefit(6);
		//dua dac tinh ung vien rst
		candcln << cal_lu_density(14);
		candcln << landSuitability[14]; 
		candcln << xet_khokhanchuyendoi(landuse, 14);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candcln << get_benefit(14);
		
		candbhk << cal_lu_density(12);
		candbhk << landSuitability[12]; 
		candbhk << xet_khokhanchuyendoi(landuse, 12);  // gias trij chuyeern ddooir tuwf Lu hien tai sang 5	
		candbhk << get_benefit(12);
		//nap cac ung vien vao danh sach candidates
		candidates << candluc;
		candidates << candtsl;
		candidates << candluk;
		candidates << candcln;
		candidates << candbhk;

//		write "madvdd cua cell :" + slandunit + " ;muc thich nghi TSL:" + landSuitability[34];
//		write "muc thich nghi LUC:" + landSuitability[ 5];
//		write "muc thich nghi LUK:" +landSuitability[ 6];
//		write "muc thich nghi CLN:" + landSuitability[14];
//		write "muc thich nghi BHK:" + landSuitability[12];
//		write "kho khan chuyen doi BHK:" + xet_khokhanchuyendoi(landuse, 12);
//		write "Loi nhuan tom:"+ get_benefit(34) +" Density 34:"+ cal_lu_density(34); 
		
		return candidates;
	}

	action select_landuse {
		list<list> cands <- landuse_eval();
		int choice <- 0;
		//if (landuse=5 or landuse=6 or landuse=14 ){//nh???ng lo???i ?????t c?? kh??? n??ng chuy???n
		choice <- weighted_means_DM(cands, creteria);
		//choice tra vi tri ung vien trong danh sach
		if (choice = 0) {
			if flip(0.05){
		//if check_suitability(madvdd,5)>0{	
			landuse <- 5;
			}
		}

		if (choice = 1) {
			if flip(0.15){
		//if check_suitability(madvdd,34)>0{
			landuse <- 34;
			}	
		}

		if (choice = 2) {
		//if check_suitability(madvdd,6)>0{
			landuse <- 6;
			//}
		}

		if (choice = 3) {
		//	if check_suitability(madvdd,14)>0{
			if flip(0.2){
				landuse <- 14;
			}
		}

		if (choice = 4) {
			if flip(0.2){
				landuse <- 12;		
			}
		}
		grid_value<-float(landuse);
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
	float xet_khokhanchuyendoi (int landuse1, int landuse2) {
		float kqkhokhanchuyendoi <- 0.0;
		if (kqkhokhanchuyendoi_map["" + landuse1 + " " + landuse2] = nil) {
		} else {
			kqkhokhanchuyendoi <- kqkhokhanchuyendoi_map["" + landuse1 + " " + landuse2];
		}
		return kqkhokhanchuyendoi;
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
	bool out_dyke;
	rgb color <- rgb(160, 255, 255);
	init {
	}
	aspect default{
//	if not out_dyke{
			draw shape color:color border:color;
		
//		}
//		else 
	} 
}

species road control: reflex {
	int id;
	rgb color <- rgb(255, 170, 50);
	init {
	}
	aspect default{
		draw shape color:rgb(255, 170, 50) border:rgb(255, 170, 50);
	}

}
species dyke {
	int  dyke_region; // 1: inside dyke; 2 : outside dyke
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
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
species salinity_obs  {
	int  salinity_level;  //1:<4; 2:	8-Apr	3	12-Aug	4	20-Dec	5 >=20
	string sal_note;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
}
species salinity_time  {
	int  salinity_time_level;  //1:	0		3:	3	6:	6	7:	>6	
	string salt_time_note;
	rgb color <- rgb(rnd(255),rnd(255),rnd(255));
}
species salinity_time_obs  {
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
	float total_rice_shrimp_h;
	float total_riceother_h;
	float total_fruit_h;
	float total_crops_h;

	init {
	}

}

experiment "LanduseModel" type: gui {
	parameter "Weight density" var: w_lancan ;
	parameter "Weight suitability" var: w_suitability ;
	parameter 'Weight ability' var: w_diff_shifting ;
	parameter 'Weight profit:' var: w_benefit ;
	output {
		display lu_sim type: java2D {
			grid land_cell;
			//species river;
			//species road;
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
//		display salinity_dynamic type:opengl{
//			//species dyke;
//			species land_cell aspect:salinity_aspect ;
////			species river;
////			species road;
//
//		}
		display salinity_dynamic2d type:java2D{
			//species dyke;
			species land_cell aspect:salinity_aspect ;
//			species river;
//			species road;
		}
//		display salinity_time_dyn type:java2D{
//			species land_cell aspect:salinity_time_aspect  ;
//		}
	}
}

experiment "Calibrate" type: batch repeat: 1 keep_seed: true until: ( time > 5 ){
	parameter 'Weight density' var: w_lancan min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight suitability:' var: w_suitability min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight difficulties' var: w_diff_shifting min: 0.1 max: 1.0 step:0.1;
	parameter 'Weight profit:' var: w_benefit min: 0.1 max: 1.0 step:0.1;
	init {
		batch_mode <- true;
	}
	
	//method genetic  maximize: v_kappa;
	method genetic pop_dim: 3 crossover_prob: 0.7 mutation_prob: 0.1 improve_sol: true stochastic_sel: false
	nb_prelim_gen: 1 max_gen: 5  maximize: v_kappa ;
}