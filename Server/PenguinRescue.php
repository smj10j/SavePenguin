<?php

$method = $_SERVER['REQUEST_METHOD'];


if($method == 'POST') {
	//save data
	
	$score = $_POST['score'];
	$userId = $_POST['userId'];
	$levelPackPath = $_POST['levelPackPath'];
	$levelPath = $_POST['levelPath'];

	//TODO: save data to database

	returnJSON(array(
		"status" => "ok"
	));
}




if($method == 'GET') {
	//return data
	
	$action = $_GET['action'];
	
	if($action == 'getWorldScores') {
	
	
		//TODO: get data from database
	
		$resp = array(
			"levels" => array(
				"Arctic1:DangerDanger" => array(
					"uniquePlays" 	=> 4000,
					"uniqueWins" 	=> 3000,
					"scoreMean"		=> 7500,
					"scoreMedian"	=> 7400,
					"scoreStdDev"	=> 500
				)
			)
		
		);
			
		returnJSON($resp);
	
	}else {
		die("error: Unknown action '$action'");
	}
}


function returnJSON($obj) {
	header('Content-type: application/json');
	die(json_encode($obj));
}
