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
				if (Enum <= 35) then
					if (Enum <= 17) then
						if (Enum <= 8) then
							if (Enum <= 3) then
								if (Enum <= 1) then
									if (Enum > 0) then
										local A = Inst[2];
										Stk[A] = Stk[A]();
									else
										local A = Inst[2];
										local C = Inst[4];
										local CB = A + 2;
										local Result = {Stk[A](Stk[A + 1], Stk[CB])};
										for Idx = 1, C do
											Stk[CB + Idx] = Result[Idx];
										end
										local R = Result[1];
										if R then
											Stk[CB] = R;
											VIP = Inst[3];
										else
											VIP = VIP + 1;
										end
									end
								elseif (Enum == 2) then
									local A = Inst[2];
									local Results, Limit = _R(Stk[A]());
									Top = (Limit + A) - 1;
									local Edx = 0;
									for Idx = A, Top do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
								elseif Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum <= 5) then
								if (Enum == 4) then
									Stk[Inst[2]] = Upvalues[Inst[3]];
								else
									local A = Inst[2];
									Stk[A] = Stk[A](Stk[A + 1]);
								end
							elseif (Enum <= 6) then
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							elseif (Enum == 7) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								local A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
							end
						elseif (Enum <= 12) then
							if (Enum <= 10) then
								if (Enum > 9) then
									local A = Inst[2];
									Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
								else
									local B = Stk[Inst[4]];
									if not B then
										VIP = VIP + 1;
									else
										Stk[Inst[2]] = B;
										VIP = Inst[3];
									end
								end
							elseif (Enum == 11) then
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							else
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							end
						elseif (Enum <= 14) then
							if (Enum == 13) then
								local A = Inst[2];
								local C = Inst[4];
								local CB = A + 2;
								local Result = {Stk[A](Stk[A + 1], Stk[CB])};
								for Idx = 1, C do
									Stk[CB + Idx] = Result[Idx];
								end
								local R = Result[1];
								if R then
									Stk[CB] = R;
									VIP = Inst[3];
								else
									VIP = VIP + 1;
								end
							else
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 15) then
							local A = Inst[2];
							do
								return Unpack(Stk, A, A + Inst[3]);
							end
						elseif (Enum > 16) then
							local A = Inst[2];
							Stk[A](Stk[A + 1]);
						elseif not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 26) then
						if (Enum <= 21) then
							if (Enum <= 19) then
								if (Enum > 18) then
									local B = Stk[Inst[4]];
									if not B then
										VIP = VIP + 1;
									else
										Stk[Inst[2]] = B;
										VIP = Inst[3];
									end
								else
									Stk[Inst[2]] = Stk[Inst[3]];
								end
							elseif (Enum > 20) then
								for Idx = Inst[2], Inst[3] do
									Stk[Idx] = nil;
								end
							else
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
							end
						elseif (Enum <= 23) then
							if (Enum == 22) then
								local A = Inst[2];
								Stk[A] = Stk[A]();
							else
								Stk[Inst[2]] = Stk[Inst[3]];
							end
						elseif (Enum <= 24) then
							local A = Inst[2];
							local Results, Limit = _R(Stk[A]());
							Top = (Limit + A) - 1;
							local Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						elseif (Enum == 25) then
							local A = Inst[2];
							local Results = {Stk[A]()};
							local Limit = Inst[4];
							local Edx = 0;
							for Idx = A, Limit do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							Stk[Inst[2]] = Upvalues[Inst[3]];
						end
					elseif (Enum <= 30) then
						if (Enum <= 28) then
							if (Enum > 27) then
								do
									return;
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
									if (Mvm[1] == 23) then
										Indexes[Idx - 1] = {Stk,Mvm[3]};
									else
										Indexes[Idx - 1] = {Upvalues,Mvm[3]};
									end
									Lupvals[#Lupvals + 1] = Indexes;
								end
								Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
							end
						elseif (Enum > 29) then
							Stk[Inst[2]] = Env[Inst[3]];
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 32) then
						if (Enum == 31) then
							do
								return Stk[Inst[2]];
							end
						else
							Stk[Inst[2]] = Env[Inst[3]];
						end
					elseif (Enum <= 33) then
						local A = Inst[2];
						do
							return Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum == 34) then
						Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 53) then
					if (Enum <= 44) then
						if (Enum <= 39) then
							if (Enum <= 37) then
								if (Enum > 36) then
									local A = Inst[2];
									local Results = {Stk[A]()};
									local Limit = Inst[4];
									local Edx = 0;
									for Idx = A, Limit do
										Edx = Edx + 1;
										Stk[Idx] = Results[Edx];
									end
								else
									do
										return Stk[Inst[2]];
									end
								end
							elseif (Enum > 38) then
								do
									return;
								end
							else
								Stk[Inst[2]] = Inst[3] ~= 0;
							end
						elseif (Enum <= 41) then
							if (Enum == 40) then
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
							else
								Stk[Inst[2]] = Inst[3];
							end
						elseif (Enum <= 42) then
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						elseif (Enum == 43) then
							if (Stk[Inst[2]] ~= Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 48) then
						if (Enum <= 46) then
							if (Enum > 45) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Top))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								local A = Inst[2];
								do
									return Stk[A], Stk[A + 1];
								end
							end
						elseif (Enum == 47) then
							local A = Inst[2];
							Stk[A](Stk[A + 1]);
						else
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum <= 50) then
						if (Enum > 49) then
							if (Stk[Inst[2]] == Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						end
					elseif (Enum <= 51) then
						local B = Inst[3];
						local K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
					elseif (Enum == 52) then
						local A = Inst[2];
						do
							return Unpack(Stk, A, Top);
						end
					else
						local B = Inst[3];
						local K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
					end
				elseif (Enum <= 62) then
					if (Enum <= 57) then
						if (Enum <= 55) then
							if (Enum == 54) then
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								local A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						elseif (Enum > 56) then
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 59) then
						if (Enum > 58) then
							for Idx = Inst[2], Inst[3] do
								Stk[Idx] = nil;
							end
						else
							Stk[Inst[2]] = {};
						end
					elseif (Enum <= 60) then
						if (Stk[Inst[2]] == Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum > 61) then
						local A = Inst[2];
						do
							return Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					else
						Stk[Inst[2]] = Inst[3];
					end
				elseif (Enum <= 67) then
					if (Enum <= 64) then
						if (Enum > 63) then
							Stk[Inst[2]] = {};
						else
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						end
					elseif (Enum <= 65) then
						local A = Inst[2];
						local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
						local Edx = 0;
						for Idx = A, Inst[4] do
							Edx = Edx + 1;
							Stk[Idx] = Results[Edx];
						end
					elseif (Enum > 66) then
						if (Stk[Inst[2]] ~= Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					else
						Stk[Inst[2]] = Inst[3] ~= 0;
					end
				elseif (Enum <= 69) then
					if (Enum == 68) then
						local A = Inst[2];
						do
							return Unpack(Stk, A, Top);
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
							if (Mvm[1] == 23) then
								Indexes[Idx - 1] = {Stk,Mvm[3]};
							else
								Indexes[Idx - 1] = {Upvalues,Mvm[3]};
							end
							Lupvals[#Lupvals + 1] = Indexes;
						end
						Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
					end
				elseif (Enum <= 70) then
					local A = Inst[2];
					Stk[A](Unpack(Stk, A + 1, Inst[3]));
				elseif (Enum > 71) then
					local A = Inst[2];
					local Results = {Stk[A](Unpack(Stk, A + 1, Top))};
					local Edx = 0;
					for Idx = A, Inst[4] do
						Edx = Edx + 1;
						Stk[Idx] = Results[Edx];
					end
				else
					VIP = Inst[3];
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!1F3Q0003063Q00747970656F6603073Q0067657467656E7603083Q0066756E6374696F6E03133Q004D61786948756253746570666F726453746F7003053Q007063612Q6C03023Q005F4703043Q007479706503053Q007461626C65030E3Q004D617869487562536B69704B65792Q0103113Q004D61786948756247616D65536372697074033E3Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F6B6F744D613073316E2F4D4158495F4855422F6D61696E2F7363722F03383Q00682Q7470733A2Q2F63646E2E6A7364656C6976722E6E65742F67682F6B6F744D613073316E2F4D4158495F485542406D61696E2F7363722F03173Q0073746570666F72642D636F756E74792D7261696C77617903113Q007363722D622Q6F7473747261702E6C7561030A3Q006C6F6164737472696E6703043Q006C6F616403043Q007761726E03283Q005B5343525D20D09DD0B5D182206C6F6164737472696E672F6C6F616420D0B2206578656375746F7203063Q00737472696E67034Q0003373Q005B5343525D207363722D622Q6F7473747261702E6C7561206E6F7420666F756E642028776F726B7370616365206F72204769744875622903053Q007072696E7403093Q005B5343525D202D3E2003083Q00746F737472696E67030E3Q00407363722D622Q6F747374726170030F3Q005B5343525D20636F6D70696C653A2003053Q00646562756703093Q0074726163656261636B03063Q00787063612Q6C03063Q005B5343525D2000883Q0012203Q00013Q001220000100024Q00083Q0002000200263C3Q000F000100030004473Q000F00010012203Q00024Q00163Q000100020020315Q00040006033Q000F00013Q0004473Q000F00010012203Q00053Q001220000100024Q00160001000100020020310001000100042Q00113Q000200010012203Q00013Q001220000100024Q00083Q0002000200263C3Q0018000100030004473Q001800010012203Q00024Q00163Q000100020006103Q0019000100010004473Q001900010012203Q00063Q001220000100074Q001200026Q000800010002000200263C00010020000100080004473Q002000010030383Q0009000A0030383Q000B000A0012290001000C3Q0012290002000D3Q0012290003000E3Q0012290004000F3Q00061B00053Q000100032Q00178Q00173Q00014Q00173Q00023Q00061B00060001000100032Q00178Q00173Q00044Q00173Q00033Q00023F000700023Q00023F000800033Q00023F000900043Q00061B000A0005000100022Q00173Q00034Q00173Q00043Q00061B000B0006000100072Q00173Q00064Q00173Q00094Q00173Q00074Q00173Q00054Q00173Q00044Q00173Q00084Q00173Q000A3Q001220000C00103Q000610000C003E000100010004473Q003E0001001220000C00113Q001220000D00074Q0012000E000C4Q0008000D00020002002643000D0047000100030004473Q00470001001220000D00123Q001229000E00134Q0011000D000200012Q00273Q00014Q0012000D000B4Q0019000D0001000E001220000F00074Q00120010000D4Q0008000F0002000200263C000F0050000100140004473Q0050000100263C000D0054000100150004473Q00540001001220000F00123Q001229001000164Q0011000F000200012Q00273Q00013Q001220000F00173Q001229001000183Q001220001100193Q0006090012005A0001000E0004473Q005A00012Q0012001200044Q00080011000200022Q00330010001000112Q0011000F000200012Q0012000F000C4Q00120010000D3Q0012290011001A4Q0007000F00110010001220001100074Q00120012000F4Q00080011000200020026430011006E000100030004473Q006E0001001220001100123Q0012290012001B3Q001220001300194Q0012001400104Q00080013000200022Q00330012001200132Q00110011000200012Q00273Q00013Q00023F001100073Q0012200012001C3Q0006030012007A00013Q0004473Q007A0001001220001200073Q0012200013001C3Q00203100130013001D2Q000800120002000200263C0012007A000100030004473Q007A00010012200012001C3Q00203100110012001D0012200012001E4Q00120013000F4Q0012001400114Q000700120014001300061000120087000100010004473Q00870001001220001400123Q0012290015001F3Q001220001600194Q0012001700134Q00080016000200022Q00330015001500162Q00110014000200012Q00273Q00013Q00083Q00063Q0003043Q007479706503053Q007461626C65030F3Q005343525F4F2Q66696369616C52617703063Q00737472696E67034Q0003063Q00696E7365727400224Q003A7Q001220000100014Q001A00026Q000800010002000200263C00010016000100020004473Q00160001001220000100014Q001A00025Q0020310002000200032Q000800010002000200263C00010016000100040004473Q001600012Q001A00015Q00203100010001000300264300010016000100050004473Q00160001001220000100023Q0020310001000100062Q001200026Q001A00035Q0020310003000300032Q0030000100030001001220000100023Q0020310001000100062Q001200026Q001A000300014Q0030000100030001001220000100023Q0020310001000100062Q001200026Q001A000300024Q00300001000300012Q001F3Q00024Q00273Q00017Q00073Q0003043Q007479706503053Q007461626C65030D3Q005343525F4C6F63616C522Q6F7403063Q00737472696E67034Q0003063Q00696E7365727403013Q002F00284Q003A7Q001220000100014Q001A00026Q000800010002000200263C00010019000100020004473Q00190001001220000100014Q001A00025Q0020310002000200032Q000800010002000200263C00010019000100040004473Q001900012Q001A00015Q00203100010001000300264300010019000100050004473Q00190001001220000100023Q0020310001000100062Q001200026Q001A00035Q002031000300030003001229000400074Q001A000500014Q00330003000300052Q0030000100030001001220000100023Q0020310001000100062Q001200026Q001A000300023Q001229000400074Q001A000500014Q00330003000300052Q0030000100030001001220000100023Q0020310001000100062Q001200026Q001A000300014Q00300001000300012Q001F3Q00024Q00273Q00017Q000A3Q0003063Q00747970656F6603023Q006F7303053Q007461626C6503043Q0074696D65028Q0003043Q006D61746803063Q0072616E646F6D025Q00408F40024Q008087C34003083Q00746F737472696E6700293Q0012203Q00013Q001220000100024Q00083Q0002000200263C3Q000E000100030004473Q000E00010012203Q00023Q0020315Q00040006033Q000E00013Q0004473Q000E00010012203Q00023Q0020315Q00042Q00163Q000100020006103Q000F000100010004473Q000F00010012293Q00053Q001220000100013Q001220000200064Q000800010002000200263C0001001F000100030004473Q001F0001001220000100063Q0020310001000100070006030001001F00013Q0004473Q001F0001001220000100063Q002031000100010007001229000200083Q001229000300094Q003700010003000200061000010020000100010004473Q00200001001229000100053Q0012200002000A4Q001200036Q00080002000200020012200003000A4Q0012000400014Q00080003000200022Q00330002000200032Q001F000200024Q00273Q00017Q000B3Q0003063Q00747970656F6603043Q0067616D6503073Q00482Q747047657403083Q0066756E6374696F6E03053Q007063612Q6C03043Q007479706503063Q00737472696E67034Q0003073Q007265717565737403053Q007461626C6503043Q00426F647901443Q001220000100013Q001220000200023Q0020310002000200032Q000800010002000200263C00010027000100040004473Q00270001001220000100053Q001220000200023Q0020310002000200032Q001200036Q0026000400014Q00070001000400020006030001001600013Q0004473Q00160001001220000300064Q0012000400024Q000800030002000200263C00030016000100070004473Q0016000100264300020016000100080004473Q001600012Q001F000200023Q001220000300053Q001220000400023Q0020310004000400032Q001200056Q00070003000500042Q0012000200044Q0012000100033Q0006030001002700013Q0004473Q00270001001220000300064Q0012000400024Q000800030002000200263C00030027000100070004473Q0027000100264300020027000100080004473Q002700012Q001F000200023Q001220000100013Q001220000200094Q000800010002000200263C00010041000100040004473Q00410001001220000100053Q00061B00023Q000100012Q00178Q00360001000200020006030001004100013Q0004473Q00410001001220000300064Q0012000400024Q000800030002000200263C000300410001000A0004473Q00410001001220000300063Q00203100040002000B2Q000800030002000200263C00030041000100070004473Q0041000100203100030002000B00264300030041000100080004473Q0041000100203100030002000B2Q001F000300024Q003B000100014Q001F000100024Q00273Q00013Q00013Q00043Q0003073Q00726571756573742Q033Q0055726C03063Q004D6574686F642Q033Q0047455400083Q0012203Q00014Q003A00013Q00022Q001A00025Q00100B0001000200020030380001000300042Q003E3Q00014Q00348Q00273Q00017Q00063Q0003043Q007479706503063Q00737472696E67034Q00030A3Q006C6F6164737472696E67030E3Q00407363722D622Q6F7473747261700002153Q001220000200014Q001200036Q000800020002000200263C00020007000100020004473Q0007000100263C3Q0009000100030004473Q000900012Q002600026Q001F000200023Q001220000200044Q001200035Q0006090004000E000100010004473Q000E0001001229000400054Q003700020004000200263C00020012000100060004473Q001200012Q002800026Q0026000200014Q001F000200024Q00273Q00017Q00073Q0003043Q007479706503063Q00737472696E67034Q0003063Q00747970656F6603093Q00777269746566696C6503083Q0066756E6374696F6E03053Q007063612Q6C01153Q001220000100014Q001200026Q000800010002000200263C00010007000100020004473Q0007000100263C3Q0008000100030004473Q000800012Q00273Q00013Q001220000100043Q001220000200054Q00080001000200020026430001000E000100060004473Q000E00012Q00273Q00013Q001220000100073Q00061B00023Q000100032Q00048Q00043Q00014Q00178Q00110001000200012Q00273Q00013Q00013Q00063Q0003063Q00747970656F66030A3Q006D616B65666F6C64657203083Q0066756E6374696F6E03053Q007063612Q6C03093Q00777269746566696C6503013Q002F00113Q0012203Q00013Q001220000100024Q00083Q0002000200263C3Q0009000100030004473Q000900010012203Q00043Q001220000100024Q001A00026Q00303Q000200010012203Q00054Q001A00015Q001229000200064Q001A000300014Q00330001000100032Q001A000200024Q00303Q000200012Q00273Q00017Q00093Q0003063Q00747970656F6603083Q007265616466696C6503083Q0066756E6374696F6E03063Q00697366696C6503063Q0069706169727303013Q0040030A3Q00776F726B73706163653A2Q033Q003F763D03073Q006769746875623A004B3Q0012203Q00013Q001220000100024Q00083Q0002000200263C3Q0026000100030004473Q002600010012203Q00013Q001220000100044Q00083Q0002000200263C3Q0026000100030004473Q002600010012203Q00054Q001A00016Q0018000100014Q002E5Q00020004473Q00240001001220000500044Q0012000600044Q00080005000200020006030005002400013Q0004473Q00240001001220000500024Q0012000600044Q00080005000200022Q001A000600014Q0012000700053Q001229000800064Q0012000900044Q00330008000800092Q00370006000800020006030006002400013Q0004473Q002400012Q0012000600053Q001229000700074Q0012000800044Q00330007000700082Q002D000600033Q00060D3Q000F000100020004473Q000F00012Q001A3Q00024Q00163Q00010002001220000100054Q001A000200034Q0018000200014Q002E00013Q00030004473Q004600012Q0012000600054Q001A000700043Q001229000800084Q001200096Q00330006000600092Q001A000700054Q0012000800064Q00080007000200022Q001A000800014Q0012000900073Q001229000A00064Q001A000B00044Q0033000A000A000B2Q00370008000A00020006030008004600013Q0004473Q004600012Q001A000800064Q0012000900074Q00110008000200012Q0012000800073Q001229000900094Q0012000A00054Q001A000B00044Q003300090009000B2Q002D000800033Q00060D0001002D000100020004473Q002D00012Q003B000100024Q002D000100034Q00273Q00017Q00013Q0003083Q00746F737472696E6701053Q001220000100014Q001200026Q003E000100024Q003400016Q00273Q00017Q00", GetFEnv(), ...);