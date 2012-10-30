<?php

$method = $_SERVER['REQUEST_METHOD'];








if($method == 'POST') {
	//save data
		
	$action = $_POST['action'];

	initDatabase();

	//save data to database

	if($action == 'saveScore') {
	
		$uuid = $_POST['UUID'];
		$score = $_POST['score'];
		$levelPackPath = $_POST['levelPackPath'];
		$levelPath = $_POST['levelPath'];

		$userId = getUserIdFromUUID($uuid);
		$levelPackId = getLevelPackIdFromLevelPackPath($levelPackPath);
		$levelId = getLevelIdFromLevelPath($levelPath);
			
		//record a win
		$result = mysql_query("INSERT INTO scores (user_id, level_pack_id, level_id, score) VALUES (".
			'"'.mysql_escape_string($userId).'",'.
			'"'.mysql_escape_string($levelPackId).'",'.
			'"'.mysql_escape_string($levelId).'",'.
			'"'.mysql_escape_string($score).'"'.
		")") or die(mysql_error());  
		
		returnJSON(array(
			"status" 		=> "ok",
			"userId"		=> $userId,
			"uuid"			=> $uuid,
			"score"			=> $score,
			"levelPackPath"	=> $levelPackPath,
			"levelPath"		=> $levelPath	
		));				
		
	}else if($action == 'savePlay') {

		$uuid = $_POST['UUID'];
		$levelPackPath = $_POST['levelPackPath'];
		$levelPath = $_POST['levelPath'];

		$userId = getUserIdFromUUID($uuid);
		$levelPackId = getLevelPackIdFromLevelPackPath($levelPackPath);
		$levelId = getLevelIdFromLevelPath($levelPath);
		
		//record a play
		$result = mysql_query("INSERT INTO plays (user_id, level_pack_id, level_id) VALUES (".
			'"'.mysql_escape_string($userId).'",'.
			'"'.mysql_escape_string($levelPackId).'",'.
			'"'.mysql_escape_string($levelId).'"'.
		")") or die(mysql_error()); 

		returnJSON(array(
			"status" 		=> "ok",
			"userId"		=> $userId,
			"uuid"			=> $uuid,
			"levelPackPath"	=> $levelPackPath,
			"levelPath"		=> $levelPath	
		));		

	}else if($action == 'saveUser') {

		$uuid = $_POST['UUID'];

		//create a user_id for the given uuid
		createUserWithUUID($uuid);
		$userId = getUserIdFromUUID($uuid);
		
		returnJSON(array(
			"status" 		=> "ok",
			"userId"		=> $userId,
			"uuid"			=> $uuid
		));				
			
	}else {
		die("error: Unknown action '$action'");
	}	
	
}









if($method == 'GET') {
	//return data
	
	$action = $_GET['action'];
	
	if($action == 'getWorldScores') {
	
		initDatabase();
		
		//TODO: get data from database

		//$result = mysql_query("SELECT count(distinct user_id) FROM scores WHERE level_pack_path=");


		$result = mysql_query("SELECT * FROM scores");
		while ($row = mysql_fetch_array($result)) {
			print_r($row);
		}

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

















function createUserWithUUID($uuid) {
	$result = mysql_query("INSERT IGNORE INTO users (uuid) VALUES (".
		'"'.mysql_escape_string($uuid).'"'.
	")") or die(mysql_error()); 
}

function createLevelPackWithLevelPackPath($levelPackPath) {
	$result = mysql_query("INSERT IGNORE INTO level_packs (level_pack_path) VALUES (".
		'"'.mysql_escape_string($levelPackPath).'"'.
	")") or die(mysql_error()); 
}

function createLevelWithLevelPath($levelPath) {
	$result = mysql_query("INSERT IGNORE INTO levels (level_path) VALUES (".
		'"'.mysql_escape_string($levelPath).'"'.
	")") or die(mysql_error()); 
}




function getUserIdFromUUID($uuid, $createIfNotExists=true) {
	$result = mysql_query("SELECT * FROM users WHERE uuid='".mysql_escape_string($uuid)."' LIMIT 1");
	while ($row = mysql_fetch_array($result)) {
		return $row['user_id'];
	}
	
	if($createIfNotExists) {
		//try and create
		createUserWithUUID($uuid);
	
		//and fetch again
		return getUserIdFromUUID($uuid, false);
	}
	return null;
}

function getLevelPackIdFromLevelPackPath($levelPackPath, $createIfNotExists=true) {
	$result = mysql_query("SELECT * FROM level_packs WHERE level_pack_path='".mysql_escape_string($levelPackPath)."' LIMIT 1");
	while ($row = mysql_fetch_array($result)) {
		return $row['level_pack_id'];
	}
	
	if($createIfNotExists) {
		//try and create
		createLevelPackWithLevelPackPath($levelPackPath);
	
		//and fetch again
		return getLevelPackIdFromLevelPackPath($levelPackPath, false);
	}
	return null;
}

function getLevelIdFromLevelPath($levelPath, $createIfNotExists=true) {
	$result = mysql_query("SELECT * FROM levels WHERE level_path='".mysql_escape_string($levelPath)."' LIMIT 1");
	while ($row = mysql_fetch_array($result)) {
		return $row['level_id'];
	}
	
	if($createIfNotExists) {
		//try and create
		createLevelWithLevelPath($levelPath);
	
		//and fetch again
		return getLevelIdFromLevelPath($levelPath, false);
	}
	return null;
}






function returnJSON($obj) {
	header('Content-type: application/json');
	die(json_encode($obj));
}

function initDatabase() {
	mysql_pconnect("localhost", "smjoneze_cqrpr2", "") or die(mysql_error());
	mysql_select_db("smjoneze_conquerllc-games-penguinrescue") or die(mysql_error());
}
