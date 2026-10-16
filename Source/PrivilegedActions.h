/***************************************************************************
 *   Copyright (C) 2009-2010 by Clockwise   *
 *   copyright@clockwise.ee   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

#import <Foundation/Foundation.h>

/// No generic root command/path API. A user-authorized session can write only
/// the fixed system hosts file through a PID/audit-token/CDHash-bound stream.
@interface PrivilegedActions : NSObject
+ (BOOL)hasAuthorizedSession;
+ (NSString*)currentSystemContents;
+ (BOOL)systemFileNeedsPermissionRepair;
+ (BOOL)fileNeedsPermissionRepairAtPath:(NSString*)path owner:(uid_t)owner;
+ (NSString*)authorizationScriptSource;
+ (BOOL)trustedDirectoryAtPath:(NSString*)path owner:(uid_t)owner;
+ (void)endSession;
+ (BOOL)writeHostsContents:(NSString*)contents allowAuthorization:(BOOL)interactive error:(NSError**)error;
// Pure construction/validation helpers are exposed for fixture-based tests.
+ (NSString*)quotedShellArgument:(NSString*)argument;
+ (NSString*)bootstrapCommandForHelper:(NSString*)path digest:(NSString*)digest
                                  pid:(pid_t)pid uid:(uid_t)uid codeHash:(NSString*)hash;
@end
