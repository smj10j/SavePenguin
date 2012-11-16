<?php

$method = $_SERVER['REQUEST_METHOD'];








if($method == 'POST') {
	//save data
		
	$action = $_POST['action'];


	//save data to database

	if($action == 'saveScore') {
	
		initDatabase();
		
		$uuid = $_POST['UUID'];
		$score = $_POST['score'];
		if($score < 0) $score = 0;
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

		initDatabase();

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

		initDatabase();

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
		
		//TODO: build summary tables to store this data
/*



CREATE TABLE IF NOT EXISTS `scores_summary` (
  `score_summary_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `level_pack_id` int(10) unsigned NOT NULL,
  `level_id` int(10) unsigned NOT NULL,
  `total_users` int(11) unsigned NOT NULL,
  `unique_plays` int(11) unsigned NOT NULL,
  `total_plays` int(11) unsigned NOT NULL,
  `unique_wins` int(11) unsigned NOT NULL,
  `total_wins` int(11) unsigned NOT NULL,
  `score_mean` int(11) unsigned NOT NULL,
  `score_median` int(11) unsigned NOT NULL,
  `score_std_dev` int(11) unsigned NOT NULL,
  `updating` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`score_summary_id`),
  UNIQUE KEY `level_pack-level-created` (`level_pack_id`,`level_id`,`created`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

*/

		
		$levels = array();
		
		//total users
		$totalUsers = 0;
		$result = mysql_query("SELECT count(*) as 'count' from users");
		while ($row = mysql_fetch_array($result)) {
			$totalUsers = $row['count'];
		}		
		
		//plays
		$result = mysql_query("SELECT level_pack_id,level_id,".
							"(SELECT level_pack_path FROM level_packs lp WHERE lp.level_pack_id=p.level_pack_id ) as 'level_pack_path', ".
							"(SELECT level_path FROM levels l WHERE l.level_id=p.level_id ) as 'level_path', ". 
							"count(distinct user_id) as 'uniquePlays',count(*) as 'totalPlays' FROM plays p GROUP BY level_pack_id,level_id");
		while ($row = mysql_fetch_array($result)) {
			$levels[$row["level_pack_path"].":".$row["level_path"]] = array(
				"levelPackId"	=> $row["level_pack_id"],
				"levelId"		=> $row["level_id"],
				"totalUsers"	=> $totalUsers,
				"uniquePlays"	=> $row["uniquePlays"],
				"totalPlays"	=> $row["totalPlays"]				
			);
		}

		//wins
		$result = mysql_query("SELECT ".
							"(SELECT level_pack_path FROM level_packs lp WHERE lp.level_pack_id=s.level_pack_id ) as 'level_pack_path', ".
							"(SELECT level_path FROM levels l WHERE l.level_id=s.level_id ) as 'level_path', ". 
							"count(distinct user_id) as 'uniqueWins',count(*) as 'totalWins' FROM scores s GROUP BY level_pack_id,level_id");
		while ($row = mysql_fetch_array($result)) {
			$levels[$row["level_pack_path"].":".$row["level_path"]]["uniqueWins"] = $row["uniqueWins"];
			$levels[$row["level_pack_path"].":".$row["level_path"]]["totalWins"] = $row["totalWins"];
		}

		//mean score
		$result = mysql_query("SELECT ".
							"(SELECT level_pack_path FROM level_packs lp WHERE lp.level_pack_id=s.level_pack_id ) as 'level_pack_path', ".
							"(SELECT level_path FROM levels l WHERE l.level_id=s.level_id ) as 'level_path', ". 
							"sum(score)/count(*) as 'scoreMean',stddev(score) as 'scoreStdDev' FROM scores s GROUP BY level_pack_id,level_id");
		while ($row = mysql_fetch_array($result)) {
			$levels[$row["level_pack_path"].":".$row["level_path"]]["scoreMean"] = floor($row["scoreMean"]);
			$levels[$row["level_pack_path"].":".$row["level_path"]]["scoreStdDev"] = floor($row["scoreStdDev"]);
		}

		foreach($levels as $key => $level) {
			//median score
			$oneQuarters = 1*floor($level['totalWins']/4);
			$levelPackId = $level["levelPackId"];
			$levelId = $level["levelId"];
			
			$result = mysql_query("SELECT score FROM scores WHERE level_pack_id=$levelPackId AND level_id=$levelId ORDER BY score ASC LIMIT $twoQuarters,1");
			while ($row = mysql_fetch_array($result)) {
				$levels[$key]["scoreMedian"] = $row["score"];
			}			
		}
					
		returnJSON(array(
			"levels" => $levels
		));
	
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

	mysql_pconnect("localhost", "smjoneze_cqrpr2", "g-)+f+=UByQ;C,S^gO") or die(mysql_error());
	mysql_select_db("smjoneze_conquerllc-games-penguinrescue") or die(mysql_error());

	//TODO: switch to new database (EC2) once pushing to savepenguin.com
	//mysql_pconnect("localhost", "savepenguin_api", "bubbles&candyA()*ASg092") or die(mysql_error());
	//mysql_select_db("savepenguin") or die(mysql_error());
}
