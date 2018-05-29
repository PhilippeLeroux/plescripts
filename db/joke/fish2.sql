-- Copyright 2018 Tanel Poder. All rights reserved. More info at http://tanelpoder.com
-- Licensed under the Apache License, Version 2.0. See LICENSE.txt for terms & conditions.


SET                                                                     LiNeSiZe 10000         PageSize 5000
SET                                                                                   TrimOut ON           Head Off
                                                                  /**/
                                                                SELECT
                                                               LISTAGG
                                                             (SUBSTR(s,
                                        MOD(r2-1,115)+1,1)) WITHIN GROUP(ORDER BY r) 
                                     FROM(SELECT rownum r,RPAD(RPAD(RPAD(RPAD(LPAD(LPAD
                               ('(',x,'('),20,' '),x+20,')'),40,' '),40+y,' '),50,'W')s FROM(
                                  SELECT CEIL(ABS(SIN(rownum/30)*13))x,CEIL(ABS(COS(rownum/9)*5))y
                                     FROM dual CONNECT BY LEVEL<=115)), (SELECT rownum r2 FROM (dual)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                          CONNECT BY LEVEL <= 50) GROUP BY MOD(r2-1, 115)    +1;
