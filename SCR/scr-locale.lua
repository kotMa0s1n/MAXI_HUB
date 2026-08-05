--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

local StrToNumber = tonumber;
local Byte = string.byte;
local Char = string.char;
local Sub = string.sub;
local Subg = string.gsub;
local Rep = string.rep;
local Concat = table.concat;
local Insert = table.insert;
local LDExp = math.ldexp;
local GetFEnv = getfenv or function()
	return _ENV;
end;
local Setmetatable = setmetatable;
local PCall = pcall;
local Select = select;
local Unpack = unpack or table.unpack;
local ToNumber = tonumber;
local function VMCall(ByteString, vmenv, ...)
	local DIP = 1;
	local repeatNext;
	ByteString = Subg(Sub(ByteString, 5), "..", function(byte)
		if (Byte(byte, 2) == 81) then
			repeatNext = StrToNumber(Sub(byte, 1, 1));
			return "";
		else
			local a = Char(StrToNumber(byte, 16));
			if repeatNext then
				local b = Rep(a, repeatNext);
				repeatNext = nil;
				return b;
			else
				return a;
			end
		end
	end);
	local function gBit(Bit, Start, End)
		if End then
			local Res = (Bit / (2 ^ (Start - 1))) % (2 ^ (((End - 1) - (Start - 1)) + 1));
			return Res - (Res % 1);
		else
			local Plc = 2 ^ (Start - 1);
			return (((Bit % (Plc + Plc)) >= Plc) and 1) or 0;
		end
	end
	local function gBits8()
		local a = Byte(ByteString, DIP, DIP);
		DIP = DIP + 1;
		return a;
	end
	local function gBits16()
		local a, b = Byte(ByteString, DIP, DIP + 2);
		DIP = DIP + 2;
		return (b * 256) + a;
	end
	local function gBits32()
		local a, b, c, d = Byte(ByteString, DIP, DIP + 3);
		DIP = DIP + 4;
		return (d * 16777216) + (c * 65536) + (b * 256) + a;
	end
	local function gFloat()
		local Left = gBits32();
		local Right = gBits32();
		local IsNormal = 1;
		local Mantissa = (gBit(Right, 1, 20) * (2 ^ 32)) + Left;
		local Exponent = gBit(Right, 21, 31);
		local Sign = ((gBit(Right, 32) == 1) and -1) or 1;
		if (Exponent == 0) then
			if (Mantissa == 0) then
				return Sign * 0;
			else
				Exponent = 1;
				IsNormal = 0;
			end
		elseif (Exponent == 2047) then
			return ((Mantissa == 0) and (Sign * (1 / 0))) or (Sign * NaN);
		end
		return LDExp(Sign, Exponent - 1023) * (IsNormal + (Mantissa / (2 ^ 52)));
	end
	local function gString(Len)
		local Str;
		if not Len then
			Len = gBits32();
			if (Len == 0) then
				return "";
			end
		end
		Str = Sub(ByteString, DIP, (DIP + Len) - 1);
		DIP = DIP + Len;
		local FStr = {};
		for Idx = 1, #Str do
			FStr[Idx] = Char(Byte(Sub(Str, Idx, Idx)));
		end
		return Concat(FStr);
	end
	local gInt = gBits32;
	local function _R(...)
		return {...}, Select("#", ...);
	end
	local function Deserialize()
		local Instrs = {};
		local Functions = {};
		local Lines = {};
		local Chunk = {Instrs,Functions,nil,Lines};
		local ConstCount = gBits32();
		local Consts = {};
		for Idx = 1, ConstCount do
			local Type = gBits8();
			local Cons;
			if (Type == 1) then
				Cons = gBits8() ~= 0;
			elseif (Type == 2) then
				Cons = gFloat();
			elseif (Type == 3) then
				Cons = gString();
			end
			Consts[Idx] = Cons;
		end
		Chunk[3] = gBits8();
		for Idx = 1, gBits32() do
			local Descriptor = gBits8();
			if (gBit(Descriptor, 1, 1) == 0) then
				local Type = gBit(Descriptor, 2, 3);
				local Mask = gBit(Descriptor, 4, 6);
				local Inst = {gBits16(),gBits16(),nil,nil};
				if (Type == 0) then
					Inst[3] = gBits16();
					Inst[4] = gBits16();
				elseif (Type == 1) then
					Inst[3] = gBits32();
				elseif (Type == 2) then
					Inst[3] = gBits32() - (2 ^ 16);
				elseif (Type == 3) then
					Inst[3] = gBits32() - (2 ^ 16);
					Inst[4] = gBits16();
				end
				if (gBit(Mask, 1, 1) == 1) then
					Inst[2] = Consts[Inst[2]];
				end
				if (gBit(Mask, 2, 2) == 1) then
					Inst[3] = Consts[Inst[3]];
				end
				if (gBit(Mask, 3, 3) == 1) then
					Inst[4] = Consts[Inst[4]];
				end
				Instrs[Idx] = Inst;
			end
		end
		for Idx = 1, gBits32() do
			Functions[Idx - 1] = Deserialize();
		end
		return Chunk;
	end
	local function Wrap(Chunk, Upvalues, Env)
		local Instr = Chunk[1];
		local Proto = Chunk[2];
		local Params = Chunk[3];
		return function(...)
			local Instr = Instr;
			local Proto = Proto;
			local Params = Params;
			local _R = _R;
			local VIP = 1;
			local Top = -1;
			local Vararg = {};
			local Args = {...};
			local PCount = Select("#", ...) - 1;
			local Lupvals = {};
			local Stk = {};
			for Idx = 0, PCount do
				if (Idx >= Params) then
					Vararg[Idx - Params] = Args[Idx + 1];
				else
					Stk[Idx] = Args[Idx + 1];
				end
			end
			local Varargsz = (PCount - Params) + 1;
			local Inst;
			local Enum;
			while true do
				Inst = Instr[VIP];
				Enum = Inst[1];
				if (Enum <= 16) then
					if (Enum <= 7) then
						if (Enum <= 3) then
							if (Enum <= 1) then
								if (Enum == 0) then
									local A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
								else
									VIP = Inst[3];
								end
							elseif (Enum > 2) then
								VIP = Inst[3];
							else
								Stk[Inst[2]] = Stk[Inst[3]];
							end
						elseif (Enum <= 5) then
							if (Enum == 4) then
								local A = Inst[2];
								local B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
							else
								do
									return Stk[Inst[2]];
								end
							end
						elseif (Enum == 6) then
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							local NewProto = Proto[Inst[3]];
							local NewUvals;
							local Indexes = {};
							NewUvals = Setmetatable({}, {__index=function(_, Key)
								local Val = Indexes[Key];
								return Val[1][Val[2]];
							end,__newindex=function(_, Key, Value)
								local Val = Indexes[Key];
								Val[1][Val[2]] = Value;
							end});
							for Idx = 1, Inst[4] do
								VIP = VIP + 1;
								local Mvm = Instr[VIP];
								if (Mvm[1] == 24) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						end
					elseif (Enum <= 11) then
						if (Enum <= 9) then
							if (Enum > 8) then
								local A = Inst[2];
								do
									return Unpack(Stk, A, A + Inst[3]);
								end
							else
								Stk[Inst[2]] = Inst[3];
							end
						elseif (Enum > 10) then
							do
								return;
							end
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 13) then
						if (Enum == 12) then
							Stk[Inst[2]] = Inst[3];
						else
							do
								return;
							end
						end
					elseif (Enum <= 14) then
						Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
					elseif (Enum == 15) then
						Stk[Inst[2]] = Env[Inst[3]];
					elseif Stk[Inst[2]] then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 25) then
					if (Enum <= 20) then
						if (Enum <= 18) then
							if (Enum == 17) then
								Stk[Inst[2]] = {};
							elseif (Stk[Inst[2]] == Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 19) then
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						else
							Stk[Inst[2]] = Upvalues[Inst[3]];
						end
					elseif (Enum <= 22) then
						if (Enum > 21) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						else
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						end
					elseif (Enum <= 23) then
						do
							return Stk[Inst[2]];
						end
					elseif (Enum == 24) then
						Stk[Inst[2]] = Stk[Inst[3]];
					else
						Stk[Inst[2]][Inst[3]] = Inst[4];
					end
				elseif (Enum <= 29) then
					if (Enum <= 27) then
						if (Enum > 26) then
							local NewProto = Proto[Inst[3]];
							local NewUvals;
							local Indexes = {};
							NewUvals = Setmetatable({}, {__index=function(_, Key)
								local Val = Indexes[Key];
								return Val[1][Val[2]];
							end,__newindex=function(_, Key, Value)
								local Val = Indexes[Key];
								Val[1][Val[2]] = Value;
							end});
							for Idx = 1, Inst[4] do
								VIP = VIP + 1;
								local Mvm = Instr[VIP];
								if (Mvm[1] == 24) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						else
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						end
					elseif (Enum > 28) then
						local A = Inst[2];
						local B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
					else
						Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
					end
				elseif (Enum <= 31) then
					if (Enum > 30) then
						Stk[Inst[2]] = {};
					else
						Stk[Inst[2]] = Env[Inst[3]];
					end
				elseif (Enum <= 32) then
					local A = Inst[2];
					Stk[A] = Stk[A](Stk[A + 1]);
				elseif (Enum == 33) then
					if (Stk[Inst[2]] == Inst[4]) then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				else
					Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!403Q0003043Q005445585403023Q00656E030A3Q007469746C655F68696E7403123Q0052696768744374726C20E28094206869646503113Q007469746C655F68696E745F6D6F62696C65030D3Q004D656E7520E28094206F70656E03093Q00686964655F68696E7403173Q0052696768744374726C20E28094206F70656E206D656E7503103Q00686964655F68696E745F6D6F62696C65030F3Q006D6F62696C655F62746E5F6D656E7503043Q004D656E75030D3Q007461625F6175746F70696C6F7403093Q004175746F70696C6F7403113Q007461625F6175746F70696C6F745F73756203253Q00436C612Q7320333537207C20566963746F726961203C3E204C65696768746F6E2043697479030B3Q007461625F72657374617274030D3Q00526F7574652052657374617274030F3Q007461625F726573746172745F737562030D3Q004175746F204E657874204C6567030B3Q007461625F6372656469747303053Q0041626F7574030F3Q007461625F637265646974735F737562031D3Q0041626F7574207468652073637269707420616E6420636F6E746163747303133Q007363725F70616E656C5F6175746F70696C6F7403113Q007363725F70616E656C5F7265737461727403143Q007363725F746F2Q676C655F6175746F70696C6F7403133Q007363725F746F2Q676C655F6E6F6C696D697473031C3Q004175746F70696C6F74202D204E6F204C696D6974732028426574612903103Q007363725F746F2Q676C655F642Q6F7273030F3Q004175746F204F70656E20442Q6F7273030E3Q007363725F746F2Q676C655F61777303083Q004175746F2041575303133Q007363725F746F2Q676C655F6E6578745F6C6567030F3Q007363725F726F7574655F7469746C6503163Q00526571756972656420747261696E202620726F757465030E3Q007363725F726F7574655F68696E7403233Q00537061776E2074686973206265666F7265207573696E6720746865207363726970743A030F3Q007363725F726F7574655F76616C756503433Q004F70657261746F72202D20436F2Q6E656374207C20436C612Q7320333537207C2053746570666F726420566963746F726961203C3E204C65696768746F6E204369747903113Q007363725F637265646974735F61626F757403763Q004D41584920485542207C2053746570666F726420436F756E7479205261696C7761790A526571756972656420737061776E3A0A4F70657261746F72202D20436F2Q6E656374207C20436C612Q7320333537207C2053746570666F726420566963746F726961203C3E204C65696768746F6E204369747903103Q007363725F62746E5F74656C656772616D03103Q0054656C656772616D206368612Q6E656C03173Q007363725F62746E5F74656C656772616D5F636F7069656403073Q00436F706965642103023Q007275031A3Q0052696768744374726C20E2809420D181D0BAD180D18BD182D18C031B3Q00D09CD0B5D0BDD18E20E2809420D0BED182D0BAD180D18BD182D18C03253Q0052696768744374726C20E2809420D0BED182D0BAD180D18BD182D18C20D0BCD0B5D0BDD18E03083Q00D09CD0B5D0BDD18E03123Q00D090D0B2D182D0BED0BFD0B8D0BBD0BED182031F3Q00D0A0D0B5D181D182D0B0D180D18220D0BCD0B0D180D188D180D183D182D0B003243Q00D090D0B2D182D0BE20D181D0BBD0B5D0B4D183D18ED189D0B8D0B920D18DD182D0B0D0BF03113Q00D09E20D181D0BAD180D0B8D0BFD182D0B503253Q00D09E20D181D0BAD180D0B8D0BFD182D0B520D0B820D0BAD0BED0BDD182D0B0D0BAD182D18B03333Q00D090D0B2D182D0BED0BFD0B8D0BBD0BED18220E2809420D0B1D0B5D0B720D0BBD0B8D0BCD0B8D182D0BED0B22028426574612903263Q00D090D0B2D182D0BE20D0BED182D0BAD180D18BD182D0B8D0B520D0B4D0B2D0B5D180D0B5D0B9030C3Q00D090D0B2D182D0BE2041575303293Q00D09DD183D0B6D0BDD18BD0B920D0BFD0BED0B5D0B7D0B420D0B820D0BCD0B0D180D188D180D183D18203403Q00D097D0B0D181D0BFD0B0D0B2D0BDD18C20D18DD182D0BE20D0BFD0B5D180D0B5D0B420D0B8D181D0BFD0BED0BBD18CD0B7D0BED0B2D0B0D0BDD0B8D0B5D0BC3A037F3Q004D41584920485542207C2053746570666F726420436F756E7479205261696C7761790AD09DD183D0B6D0BDD18BD0B920D181D0BFD0B0D0B2D0BD3A0A4F70657261746F72202D20436F2Q6E656374207C20436C612Q7320333537207C2053746570666F726420566963746F726961203C3E204C65696768746F6E204369747903133Q0054656C656772616D20D0BAD0B0D0BDD0B0D0BB03173Q00D0A1D0BAD0BED0BFD0B8D180D0BED0B2D0B0D0BDD0BE2103013Q0074003D4Q001F8Q001F00013Q00012Q001F00023Q00140030190002000300040030190002000500060030190002000700080030190002000900060030190002000A000B0030190002000C000D0030190002000E000F00301900020010001100301900020012001300301900020014001500301900020016001700301900020018000D0030190002001900110030190002001A000D0030190002001B001C0030190002001D001E0030190002001F00200030190002002100130030190002002200230030190002002400250030190002002600270030190002002800290030190002002A002B0030190002002C002D0010220001000200020010223Q0001000100201A00013Q00012Q001F00023Q001400301900020003002F0030190002000500300030190002000700310030190002000900300030190002000A00320030190002000C00330030190002000E000F0030190002001000340030190002001200350030190002001400360030190002001600370030190002001800330030190002001900340030190002001A00330030190002001B00380030190002001D00390030190002001F003A00301900020021003500301900020022003B00301900020024003C00301900020026002700301900020028003D0030190002002A003E0030190002002C003F0010220001002E000200060700013Q000100012Q00187Q0010223Q004000012Q00173Q00024Q000B3Q00013Q00013Q00063Q0003023Q00656E03043Q007479706503063Q00737472696E6703053Q006C6F77657203023Q00727503043Q005445585402213Q00120C000200013Q00121E000300024Q000200046Q00200003000200020026120003000B000100030004033Q000B000100201D00033Q00042Q00200003000200020026120003000B000100050004033Q000B000100120C000200054Q001600035Q00201A0003000300062Q000E000300030002002Q060003001500013Q0004033Q001500012Q000E000400030001002Q060004001500013Q0004033Q001500012Q000E0004000300012Q0017000400024Q001600045Q00201A00040004000600201A000400040001002Q060004001F00013Q0004033Q001F00012Q000E000500040001002Q060005001F00013Q0004033Q001F00012Q000E0005000400012Q0017000500024Q0017000100024Q000B3Q00017Q00", GetFEnv(), ...);
