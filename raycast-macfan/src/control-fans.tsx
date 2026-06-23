import {
  Action,
  ActionPanel,
  Form,
  List,
  openExtensionPreferences,
  showToast,
  Toast,
  useNavigation
} from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import {
  defaultTargetRPM,
  displayName,
  FanInfo,
  modeTitle,
  percentOfRange,
  readFans,
  resetFanControl,
  safeMaximumRPM,
  safeMinimumRPM,
  setAllFansMaximum,
  setFanMode,
  setFanSpeed,
  toErrorMessage
} from "./macfan";

export default function Command() {
  const [fans, setFans] = useState<FanInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string>();

  const loadFans = useCallback(async () => {
    setIsLoading(true);
    setError(undefined);

    try {
      setFans(await readFans());
    } catch (error) {
      setFans([]);
      setError(toErrorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadFans();
  }, [loadFans]);

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search fans">
      {error ? (
        <List.EmptyView
          title="Could not load fans"
          description={error}
          actions={
            <ActionPanel>
              <Action title="Refresh" shortcut={{ modifiers: ["cmd"], key: "r" }} onAction={loadFans} />
              <Action title="Open Extension Preferences" onAction={openExtensionPreferences} />
            </ActionPanel>
          }
        />
      ) : fans.length === 0 && !isLoading ? (
        <List.EmptyView
          title="No fans found"
          description="macfanctl did not report any controllable fans."
          actions={
            <ActionPanel>
              <Action title="Refresh" shortcut={{ modifiers: ["cmd"], key: "r" }} onAction={loadFans} />
            </ActionPanel>
          }
        />
      ) : (
        <List.Section title="Fans">
          {fans.map((fan) => (
            <FanListItem key={fan.id} fan={fan} reload={loadFans} />
          ))}
        </List.Section>
      )}
    </List>
  );
}

function FanListItem({ fan, reload }: { fan: FanInfo; reload: () => Promise<void> }) {
  const title = displayName(fan);
  const minimum = safeMinimumRPM(fan);
  const maximum = safeMaximumRPM(fan);

  return (
    <List.Item
      title={title}
      subtitle={`${modeTitle(fan.mode)} - ${percentOfRange(fan)}%`}
      accessories={[
        { text: `${fan.currentRPM} RPM` },
        { text: `Target ${fan.targetRPM ?? "--"} RPM` }
      ]}
      actions={
        <ActionPanel>
          <Action.Push title="Set Custom RPM" target={<SetSpeedForm fan={fan} reload={reload} />} />
          <Action
            title="Set Maximum"
            shortcut={{ modifiers: ["cmd"], key: "m" }}
            onAction={() => runFanAction(`Setting ${title} to Max`, `${title} set to Max`, reload, () => setFanSpeed(fan.id, maximum))}
          />
          <Action
            title="Return to Auto"
            shortcut={{ modifiers: ["cmd"], key: "a" }}
            onAction={() => runFanAction(`Returning ${title} to Auto`, `${title} returned to Auto`, reload, () => setFanMode(fan.id, "auto"))}
          />
          <Action
            title="Set Manual"
            onAction={() => runFanAction(`Setting ${title} to Manual`, `${title} set to Manual`, reload, () => setFanMode(fan.id, "manual"))}
          />
          <ActionPanel.Section>
            <Action
              title="All Fans Max"
              shortcut={{ modifiers: ["cmd", "shift"], key: "m" }}
              onAction={() => runFanAction("Setting fans to Max", "Fans set to Max", reload, setAllFansMaximum)}
            />
            <Action
              title="All Fans Auto"
              shortcut={{ modifiers: ["cmd", "shift"], key: "a" }}
              onAction={() => runFanAction("Returning fans to Auto", "Fans returned to Auto", reload, resetFanControl)}
            />
          </ActionPanel.Section>
          <ActionPanel.Section>
            <Action title="Refresh" shortcut={{ modifiers: ["cmd"], key: "r" }} onAction={reload} />
          </ActionPanel.Section>
          <ActionPanel.Section title="Range">
            <Action.CopyToClipboard title="Copy Minimum RPM" content={String(minimum)} />
            <Action.CopyToClipboard title="Copy Maximum RPM" content={String(maximum)} />
          </ActionPanel.Section>
        </ActionPanel>
      }
    />
  );
}

function SetSpeedForm({ fan, reload }: { fan: FanInfo; reload: () => Promise<void> }) {
  const { pop } = useNavigation();
  const minimum = safeMinimumRPM(fan);
  const maximum = safeMaximumRPM(fan);
  const title = displayName(fan);

  async function handleSubmit(values: { rpm: string }) {
    const rpm = Number.parseInt(values.rpm, 10);

    if (!Number.isFinite(rpm)) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Enter a valid RPM"
      });
      return;
    }

    if (rpm < minimum || rpm > maximum) {
      await showToast({
        style: Toast.Style.Failure,
        title: "RPM is outside this fan's range",
        message: `${minimum}-${maximum} RPM`
      });
      return;
    }

    await runFanAction(`Setting ${title} to ${rpm} RPM`, `${title} set to ${rpm} RPM`, reload, () => setFanSpeed(fan.id, rpm));
    pop();
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Set RPM" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Description text={`${title}: ${minimum}-${maximum} RPM`} />
      <Form.TextField id="rpm" title="RPM" defaultValue={String(defaultTargetRPM(fan))} placeholder={String(defaultTargetRPM(fan))} />
    </Form>
  );
}

async function runFanAction(
  loadingTitle: string,
  successTitle: string,
  reload: () => Promise<void>,
  action: () => Promise<unknown>
): Promise<void> {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: loadingTitle
  });

  try {
    await action();
    await reload();
    toast.style = Toast.Style.Success;
    toast.title = successTitle;
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Fan command failed";
    toast.message = toErrorMessage(error);
  }
}
