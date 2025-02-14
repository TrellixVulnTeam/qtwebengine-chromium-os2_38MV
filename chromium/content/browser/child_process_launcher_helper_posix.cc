// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "content/browser/child_process_launcher_helper_posix.h"

#include "base/command_line.h"
#include "base/metrics/field_trial.h"
#include "base/posix/global_descriptors.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/string_util.h"
#include "build/build_config.h"
#include "content/browser/posix_file_descriptor_info_impl.h"
#include "content/public/browser/content_browser_client.h"
#include "content/public/common/content_client.h"
#include "content/public/common/content_descriptor_keys.h"
#include "content/public/common/content_descriptors.h"
#include "content/public/common/content_switches.h"
#include "mojo/public/cpp/platform/platform_channel_endpoint.h"
#include "services/service_manager/embedder/shared_file_util.h"
#include "services/service_manager/embedder/switches.h"

namespace content {
namespace internal {

namespace {

base::PlatformFile OpenFileIfNecessary(const base::FilePath& path,
                                       base::MemoryMappedFile::Region* region) {
  static auto* opened_files = new std::map<
      base::FilePath,
      std::pair<base::PlatformFile, base::MemoryMappedFile::Region>>;

  const auto& iter = opened_files->find(path);
  if (iter != opened_files->end()) {
    *region = iter->second.second;
    return iter->second.first;
  }
  base::File file = OpenFileToShare(path, region);
  if (!file.IsValid()) {
    return base::kInvalidPlatformFile;
  }
  // g_opened_files becomes the owner of the file descriptor.
  base::PlatformFile fd = file.TakePlatformFile();
  (*opened_files)[path] = std::make_pair(fd, *region);
  return fd;
}

}  // namespace

std::unique_ptr<PosixFileDescriptorInfo> CreateDefaultPosixFilesToMap(
    int child_process_id,
    const mojo::PlatformChannelEndpoint& mojo_channel_remote_endpoint,
    std::map<std::string, base::FilePath> files_to_preload,
    const std::string& process_type,
    base::CommandLine* command_line) {
  std::unique_ptr<PosixFileDescriptorInfo> files_to_register(
      PosixFileDescriptorInfoImpl::Create());

#if !defined(OS_MACOSX)
#if !defined(OS_OS2)
  // Mac and OS/2 shared memory doesn't use file descriptors.
  int fd = base::FieldTrialList::GetFieldTrialDescriptor();
  if (fd != -1)
    files_to_register->Share(service_manager::kFieldTrialDescriptor, fd);
#endif

  DCHECK(mojo_channel_remote_endpoint.is_valid());
  files_to_register->Share(
      service_manager::kMojoIPCChannel,
      mojo_channel_remote_endpoint.platform_handle().GetFD().get());

  // TODO(jcivelli): remove this "if defined" by making
  // GetAdditionalMappedFilesForChildProcess a no op on Mac.
  GetContentClient()->browser()->GetAdditionalMappedFilesForChildProcess(
      *command_line, child_process_id, files_to_register.get());
#endif

  // Also include the files specified explicitly by |files_to_preload|.
  base::GlobalDescriptors::Key key = kContentDynamicDescriptorStart;
  service_manager::SharedFileSwitchValueBuilder file_switch_value_builder;
  for (const auto& key_path_iter : files_to_preload) {
#if !defined(V8_USE_EXTERNAL_STARTUP_DATA)
    if (key_path_iter.first == content::kV8SnapshotDataDescriptor ||
        key_path_iter.first == content::kV8ContextSnapshotDataDescriptor) {
      continue;
    }
#endif  // !V8_USE_EXTERNAL_STARTUP_DATA
    base::MemoryMappedFile::Region region;
    base::PlatformFile file =
        OpenFileIfNecessary(key_path_iter.second, &region);
    if (file == base::kInvalidPlatformFile) {
      DLOG(WARNING) << "Ignoring invalid file " << key_path_iter.second.value();
      continue;
    }
    file_switch_value_builder.AddEntry(key_path_iter.first, key);
    files_to_register->ShareWithRegion(key, file, region);
    key++;
    DCHECK(key < kContentDynamicDescriptorMax);
  }
  command_line->AppendSwitchASCII(service_manager::switches::kSharedFiles,
                                  file_switch_value_builder.switch_value());


  return files_to_register;
}

}  // namespace internal
}  // namespace content
