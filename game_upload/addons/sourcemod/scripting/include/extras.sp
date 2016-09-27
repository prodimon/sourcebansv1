// Небольшое расширение.
// Сделано LegenD(legend2360) и находится в статусе dev. правка от GeParD
// -SourceBans.net-

#define SB_VERSION /*Для версии:*/"1.4.10"

new bantime[MAXPLAYERS+1] = {-1, ...}, Handle:TimerGetEndBan[MAXPLAYERS+1];

public VerifyInsert(Handle:owner, Handle:hndl, const String:error[], any:dataPack)
{
	if(dataPack == INVALID_HANDLE)
	{
		LogToFile(logFile, "Ban Failed: %s", error);
		return;
	}
	
	if(hndl == INVALID_HANDLE || error[0])
	{
		LogToFile(logFile, "Verify Insert Query Failed: %s", error);
		new admin = ReadPackCell(dataPack);
		SetPackPosition(dataPack, 32);
		new time = ReadPackCell(dataPack);
		new Handle:reasonPack = Handle:ReadPackCell(dataPack);
		decl String:reason[128];
		ReadPackString(reasonPack, reason, sizeof(reason));
		decl String:name[50];
		ReadPackString(dataPack, name, sizeof(name));
		decl String:auth[30];
		ReadPackString(dataPack, auth, sizeof(auth));
		decl String:ip[20];
		ReadPackString(dataPack, ip, sizeof(ip));
		decl String:adminAuth[30];
		ReadPackString(dataPack, adminAuth, sizeof(adminAuth));
		decl String:adminIp[20];
		ReadPackString(dataPack, adminIp, sizeof(adminIp));
		ResetPack(dataPack);
		ResetPack(reasonPack);

		PlayerDataPack[admin] = INVALID_HANDLE;
		UTIL_InsertTempBan(time, name, auth, ip, reason, adminAuth, adminIp, Handle:dataPack);
		return;
	}

	new admin = ReadPackCell(dataPack);
	new client = ReadPackCell(dataPack);
	
	if( !IsClientConnected(client) || IsFakeClient(client) )
		return;
	
	SetPackPosition(dataPack, 24);
	new UserId = ReadPackCell(dataPack);
	new time = ReadPackCell(dataPack);
	new Handle:ReasonPack = Handle:ReadPackCell(dataPack);

	decl String:Name[64], String:Reason[128];

	ReadPackString(dataPack, Name, sizeof(Name));
	ReadPackString(ReasonPack, Reason, sizeof(Reason));

	if (!time)
	{
		if (Reason[0] == '\0')
		{
			ShowActivityEx(admin, Prefix, "%t", "Permabanned player", Name);
		}
		else
		{
			ShowActivityEx(admin, Prefix, "%t","Permabanned player reason", Name, Reason);
		}
	}
	else
	{
		if (Reason[0] == '\0')
		{
			ShowActivityEx(admin, Prefix, "%t", "Banned player", Name, time);
		}
		else
		{
			ShowActivityEx(admin, Prefix, "%t", "Banned player reason", Name, time, Reason);
		}
	}

	LogAction(admin, client, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", admin, client, time, Reason);

	if(PlayerDataPack[admin] != INVALID_HANDLE)
	{
		CloseHandle(PlayerDataPack[admin]);
		CloseHandle(ReasonPack);
		PlayerDataPack[admin] = INVALID_HANDLE;
	}

	if(GetClientUserId(client) == UserId)
	{
		decl String:timestring[128];
		
		/*
		//Правильно будет, коротко и быстро
		switch(time)
		{
			case 0:		strcopy(timestring, sizeof(timestring), "Навсегда");
			case 60:	strcopy(timestring, sizeof(timestring), "1 час");
			case 120:	strcopy(timestring, sizeof(timestring), "2 часа");
			case 180:	strcopy(timestring, sizeof(timestring), "4 часа");
			default:	FormatEx(timestring, sizeof(timestring), "%i минут(ы)", time);
				
		}
		*/
		switch(time)
		{
			case 0:			strcopy(timestring, sizeof(timestring), "Навсегда");
			case 60:		strcopy(timestring, sizeof(timestring), "1 час");
			case 120:		strcopy(timestring, sizeof(timestring), "2 часа");
			case 180:		strcopy(timestring, sizeof(timestring), "4 часа");
			case 1440:		strcopy(timestring, sizeof(timestring), "1 день");
			case 2880:		strcopy(timestring, sizeof(timestring), "2 дня");
			case 4320:		strcopy(timestring, sizeof(timestring), "3 дня");
			case 5760:		strcopy(timestring, sizeof(timestring), "5 дней");
			case 8640:		strcopy(timestring, sizeof(timestring), "6 дней");
			case 10080:		strcopy(timestring, sizeof(timestring), "1 неделя");
			case 30240:		strcopy(timestring, sizeof(timestring), "3 недели");
			case 43200:		strcopy(timestring, sizeof(timestring), "1 месяц");
			case 86400:		strcopy(timestring, sizeof(timestring), "2 месяца");
			case 129600:	strcopy(timestring, sizeof(timestring), "3 месяца");
			default:		FormatEx(timestring, sizeof(timestring), "%i минут(ы)", time);	
		}

		KickClient(client, "%t", "Banned Check Site", Reason, timestring, WebsiteAddress);
	}
}

public VerifyBan(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	decl String:clientName[64],
		 String:clientAuth[64],
		 String:clientIp[64];
	new client = GetClientOfUserId(userid);
	
	if(!client)
		return;

	if(hndl == INVALID_HANDLE)
	{
		LogToFile(logFile, "Verify Ban Query Failed: %s", error);
		PlayerRecheck[client] = CreateTimer(RetryTime, ClientRecheck, client);
		return;
	}

	GetClientIP(client, clientIp, sizeof(clientIp));
	GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	GetClientName(client, clientName, sizeof(clientName));

	if(SQL_GetRowCount(hndl) > 0)
	{
		//decl String:buffer[40];
		decl String:Name[128];
		decl String:Query[512];
		
		SQL_EscapeString(Database, clientName, Name, sizeof(Name));
		if( serverID == -1 )
		{
			FormatEx(Query, sizeof(Query), "INSERT INTO %s_banlog (sid ,time ,name ,bid) VALUES  \
				((SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0,1), UNIX_TIMESTAMP(), '%s', \
				(SELECT bid FROM %s_bans WHERE ((type = 0 AND authid REGEXP '^STEAM_[0-9]:%s$') OR (type = 1 AND ip = '%s')) AND RemoveType IS NULL LIMIT 0,1))", 
				DatabasePrefix, DatabasePrefix, ServerIp, ServerPort, Name, DatabasePrefix, clientAuth[8], clientIp);
		}
		else
		{
			FormatEx(Query, sizeof(Query), "INSERT INTO %s_banlog (sid ,time ,name ,bid) VALUES  \
				(%d, UNIX_TIMESTAMP(), '%s', \
				(SELECT bid FROM %s_bans WHERE ((type = 0 AND authid REGEXP '^STEAM_[0-9]:%s$') OR (type = 1 AND ip = '%s')) AND RemoveType IS NULL LIMIT 0,1))", 
				DatabasePrefix, serverID, Name, DatabasePrefix, clientAuth[8], clientIp);
		}

		SQL_TQuery(Database, ErrorCheckCallback, Query, client, DBPrio_High);

		/* FormatEx(buffer, sizeof(buffer), "banid 5 %s", clientAuth);
		ServerCommand(buffer); */

		TimerGetEndBan[client] = CreateTimer(0.5, RunTimerGetEndBan, client);
		return;
	}
#if defined DEBUG
	LogToFile(logFile, "%s is NOT banned.", clientAuth);
#endif

	PlayerStatus[client] = true;
}

stock UTIL_InsertTempBan(time, const String:name[], const String:auth[], const String:ip[], const String:reason[], const String:adminAuth[], const String:adminIp[], Handle:dataPack)
{
	ReadPackCell(dataPack);
	new client = ReadPackCell(dataPack);
	SetPackPosition(dataPack, 40);
	new Handle:reasonPack = Handle:ReadPackCell(dataPack);
	if(reasonPack != INVALID_HANDLE)
	{
		CloseHandle(reasonPack);
	}
	CloseHandle(dataPack);
	
	// we add a temporary ban and then add the record into the queue to be processed when the database is available
	decl String:buffer[50];
	Format(buffer, sizeof(buffer), "banid %d %s", ProcessQueueTime, auth);
	ServerCommand(buffer);
	if(IsClientInGame(client))
		KickClient(client, "%t", "Banned Check Site", reason, time, WebsiteAddress);
	
	decl String:banName[128];
	decl String:banReason[256];
	decl String:query[512];
	SQL_EscapeString(SQLiteDB, name, banName, sizeof(banName));
	SQL_EscapeString(SQLiteDB, reason, banReason, sizeof(banReason));
	FormatEx(	query, sizeof(query), "INSERT INTO queue VALUES ('%s', %i, %i, '%s', '%s', '%s', '%s', '%s')", 
				auth, time, GetTime(), banReason, banName, ip, adminAuth, adminIp);
	SQL_TQuery(SQLiteDB, ErrorCheckCallback, query);
}

stock PrepareBan(client, target, time, String:reason[], size)
{
#if defined DEBUG
			LogToFile(logFile, "PrepareBan()");
#endif
	if(!target || !IsClientInGame(target))
		return;
	decl String:authid[64], String:name[32];
	GetClientAuthString(target, authid, sizeof(authid));
	GetClientName(target, name, sizeof(name));

	
	if(CreateBan(client, target, time, reason))
	{
		if (!time)
		{
			if (reason[0] == '\0')
			{
				ShowActivity(client, "%t", "Permabanned player", name);
			} else {
				ShowActivity(client, "%t", "Permabanned player reason", name, reason);
			}
		} else {
			if (reason[0] == '\0')
			{
				ShowActivity(client, "%t", "Banned player", name, time);
			} else {
				ShowActivity(client, "%t", "Banned player reason", name, time, reason);
			}
		}
		LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);
		
		if(time > 5 || time == 0)
			time = 5;
	}
	
	g_BanTarget[client] = -1;
	g_BanTime[client] = -1;
}

public Action:RunTimerGetEndBan(Handle:timer, any:client)
{
	decl String:steamid[32];
	if(IsClientConnected(client) && GetClientAuthString(client, steamid, sizeof(steamid)))	
	{
		new String:query[125];
		FormatEx(query, sizeof(query), 
		
		//ends  - 0 ячейка
		//reason - 1 ячейка
		//length - 2 ячейка
		"SELECT ends, reason, length FROM %s_bans	WHERE authid = '%s' AND RemoveType IS NULL",
		DatabasePrefix,
		steamid);
		SQL_TQuery(Database, SQL_GetEndBan, query, GetClientUserId(client), DBPrio_High);
	}

	TimerGetEndBan[client] = INVALID_HANDLE;
}


public SQL_GetEndBan(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("SourceBans - %s", error);
		return;
	}

	new client = GetClientOfUserId(userid);
	decl String:endstime[64]; 
	decl String:reason[128];

	if (client < 1) return;
	
	if(SQL_FetchRow(hndl))
	{
		bantime[client] = SQL_FetchInt(hndl, 0);				// это запрос номер 1, берем время окончания бана
		SQL_FetchString(hndl, 1, reason, sizeof(reason));		// это запрос номер 2, берем причину бана
		if(SQL_FetchInt(hndl, 2) == 0)							// это запрос номер 3, берем длину бана
			strcopy(endstime, sizeof(endstime), "Никогда");
		else
			FormatTime(endstime, sizeof(endstime), NULL_STRING, bantime[client]);
			
		//Arleady ПРАВИЛЬНО БУДЕТ Already    ()
		KickClient(client, "%t", "Already banned", reason, endstime, WebsiteAddress);
	}

	bantime[client] = -1;
}